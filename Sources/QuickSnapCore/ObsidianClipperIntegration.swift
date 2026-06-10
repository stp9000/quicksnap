import AppKit
import Foundation

struct BrowserPageSourcePayload {
    let urlString: String
    let pageTitle: String
    let html: String
    let canonicalURL: String
    let metaDescription: String
    let author: String
    let publishedDate: String
    let siteName: String
    let wordCount: Int
    let rawHTMLCharacterCount: Int
    let filteredHTMLCharacterCount: Int
}

struct MarkdownHelperExtractionResult {
    let engine: String
    let title: String
    let author: String
    let published: String
    let excerpt: String
    let canonicalURL: String
    let site: String
    let wordCount: Int
    let markdown: String
    let error: String

    var succeeded: Bool {
        !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private final class LockedDataBuffer {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        let snapshot = storage
        lock.unlock()
        return snapshot
    }
}

enum BrowserPageSourceResolver {
    private struct BrowserScript {
        let appName: String
        let bundleIdentifier: String
        let source: String
    }

    private static let chromiumAppNames = ["Google Chrome", "Arc", "Brave Browser", "Microsoft Edge"]
    private static let extractionJavaScript = """
    JSON.stringify((() => {
        const normalize = value => (value || '').replace(/\\s+/g, ' ').trim();
        const pickAttr = (selector, attr) => normalize(document.querySelector(selector)?.getAttribute?.(attr) || '');
        const pickText = selectors => {
            for (const selector of selectors) {
                const node = document.querySelector(selector);
                const text = normalize(node?.innerText || node?.textContent || '');
                if (text) return text;
            }
            return '';
        };
        const rawHTML = document.documentElement ? document.documentElement.outerHTML : "";
        const root = document.documentElement ? document.documentElement.cloneNode(true) : null;
        if (root) {
            root.querySelectorAll('script, style, noscript').forEach(node => node.remove());
        }
        const filteredHTML = root ? root.outerHTML : "";
        const bodyText = normalize(document.body?.innerText || document.body?.textContent || "");
        const canonicalURL = pickAttr('link[rel="canonical"]', 'href') || pickAttr('meta[property="og:url"]', 'content') || location.href || "";
        const metaDescription = pickAttr('meta[name="description"]', 'content') || pickAttr('meta[property="og:description"]', 'content');
        const author = pickAttr('meta[name="author"]', 'content') || pickAttr('meta[property="article:author"]', 'content') || pickText(['[rel="author"]', '.byline', '.author', '[itemprop="author"]']);
        const publishedDate = pickAttr('meta[property="article:published_time"]', 'content') || pickAttr('meta[name="article:published_time"]', 'content') || pickAttr('time[datetime]', 'datetime');
        const siteName = pickAttr('meta[property="og:site_name"]', 'content') || location.hostname || "";
        return {
            url: location.href || "",
            title: document.title || "",
            html: filteredHTML,
            canonicalURL,
            metaDescription,
            author,
            publishedDate,
            siteName,
            wordCount: bodyText ? bodyText.split(/\\s+/).filter(Boolean).length : 0,
            rawHTMLCharacterCount: rawHTML.length,
            filteredHTMLCharacterCount: filteredHTML.length
        };
    })())
    """

    static func resolve(for context: FrontmostCaptureContext) -> BrowserPageSourcePayload? {
        if context.bundleIdentifier == "com.apple.Safari" || context.sourceApp == "Safari" {
            let source = """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                set pageJSON to do JavaScript "\(escapedForJavaScriptLiteral(extractionJavaScript))" in current tab of front window
                return pageJSON
            end tell
            """
            return run(script: BrowserScript(appName: "Safari", bundleIdentifier: "com.apple.Safari", source: source))
        }

        guard chromiumAppNames.contains(context.sourceApp) else {
            return nil
        }

        let source = """
        tell application "\(context.sourceApp)"
            if (count of windows) is 0 then return ""
            set pageJSON to execute active tab of front window javascript "\(escapedForJavaScriptLiteral(extractionJavaScript))"
            return pageJSON
        end tell
        """
        return run(script: BrowserScript(appName: context.sourceApp, bundleIdentifier: context.bundleIdentifier ?? "", source: source))
    }

    private static func run(script: BrowserScript) -> BrowserPageSourcePayload? {
        guard let appleScript = NSAppleScript(source: script.source) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error != nil {
            return nil
        }

        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty,
              let data = value.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let urlString = (json["url"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let pageTitle = (json["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let html = (json["html"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalURL = (json["canonicalURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let metaDescription = (json["metaDescription"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let author = (json["author"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let publishedDate = (json["publishedDate"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let siteName = (json["siteName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = json["wordCount"] as? Int ?? 0
        let rawHTMLCharacterCount = json["rawHTMLCharacterCount"] as? Int ?? 0
        let filteredHTMLCharacterCount = json["filteredHTMLCharacterCount"] as? Int ?? 0
        guard !html.isEmpty else { return nil }
        return BrowserPageSourcePayload(
            urlString: urlString,
            pageTitle: pageTitle,
            html: html,
            canonicalURL: canonicalURL,
            metaDescription: metaDescription,
            author: author,
            publishedDate: publishedDate,
            siteName: siteName,
            wordCount: wordCount,
            rawHTMLCharacterCount: rawHTMLCharacterCount,
            filteredHTMLCharacterCount: filteredHTMLCharacterCount
        )
    }

    private static func escapedForJavaScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

enum ObsidianClipperHelper {
    private static let helperDirectoryName = "ObsidianClipperHelper"
    private static let helperRuntimeDirectoryName = "HelperRuntime"
    private static let repoRootURL: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()
    private static var isPackagedApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func extract(urlString: String, pageTitle: String, html: String?) throws -> MarkdownHelperExtractionResult {
        let helperDirectory = try helperDirectoryURL()
        let helperScript = helperDirectory.appendingPathComponent("clipper-helper.mjs")
        let nodeBinary = try nodeBinaryURL()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("quicksnap-clipper-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var input: [String: String] = [
            "url": urlString,
            "pageTitle": pageTitle
        ]
        if let html, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input["html"] = html
        }
        let inputData = try JSONSerialization.data(withJSONObject: input, options: [])
        try inputData.write(to: tempURL, options: .atomic)

        let process = Process()
        process.executableURL = nodeBinary
        process.currentDirectoryURL = helperDirectory
        process.arguments = [helperScript.path, tempURL.path]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let outputBuffer = LockedDataBuffer()
        let errorBuffer = LockedDataBuffer()
        stdout.fileHandleForReading.readabilityHandler = { handle in
            outputBuffer.append(handle.availableData)
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            errorBuffer.append(handle.availableData)
        }
        defer {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
        }

        try process.run()
        process.waitUntilExit()

        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        outputBuffer.append(stdout.fileHandleForReading.readDataToEndOfFile())
        errorBuffer.append(stderr.fileHandleForReading.readDataToEndOfFile())

        let outputData = outputBuffer.data
        let errorData = errorBuffer.data
        let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard let json = parsedJSON(from: outputData) else {
            let diagnostic = "The Markdown helper returned unreadable output (\(outputData.count) bytes, exit status \(process.terminationStatus))."
            throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorText.isEmpty ? diagnostic : errorText
            ])
        }

        return MarkdownHelperExtractionResult(
            engine: (json["engine"] as? String ?? "obsidian_clipper_helper").trimmingCharacters(in: .whitespacesAndNewlines),
            title: (json["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            author: (json["author"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            published: (json["published"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            excerpt: (json["excerpt"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            canonicalURL: (json["canonicalURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            site: (json["site"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            wordCount: json["wordCount"] as? Int ?? 0,
            markdown: (json["markdown"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            error: (json["error"] as? String ?? errorText).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func parsedJSON(from data: Data) -> [String: Any]? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines.reversed() where line.hasPrefix("{") && line.hasSuffix("}") {
            if let lineData = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                return json
            }
        }

        var cursor = trimmed.startIndex
        while cursor < trimmed.endIndex {
            if trimmed[cursor] == "{",
               let candidate = balancedJSONObjectSubstring(in: trimmed, startingAt: cursor),
               let candidateData = candidate.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: candidateData) as? [String: Any] {
                return json
            }
            cursor = trimmed.index(after: cursor)
        }
        return nil
    }

    private static func balancedJSONObjectSubstring(in text: String, startingAt startIndex: String.Index) -> String? {
        var depth = 0
        var isInString = false
        var isEscaped = false
        var cursor = startIndex

        while cursor < text.endIndex {
            let character = text[cursor]
            if isInString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInString = false
                }
            } else if character == "\"" {
                isInString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[startIndex...cursor])
                }
                if depth < 0 {
                    return nil
                }
            }
            cursor = text.index(after: cursor)
        }

        return nil
    }

    private static func helperDirectoryURL() throws -> URL {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(helperDirectoryName, isDirectory: true),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        if isPackagedApp {
            throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "The bundled Obsidian Clipper helper could not be found."
            ])
        }

        let repoURL = repoRootURL.appendingPathComponent("Vendor").appendingPathComponent(helperDirectoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: repoURL.path) {
            return repoURL
        }

        throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "The bundled Obsidian Clipper helper could not be found."
        ])
    }

    private static func nodeBinaryURL() throws -> URL {
        if let bundledNode = bundledNodeURL(),
           FileManager.default.isExecutableFile(atPath: bundledNode.path) {
            return bundledNode
        }

        if isPackagedApp {
            throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "The bundled Node.js runtime could not be found."
            ])
        }

        var candidates: [URL] = []
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["PATH"] {
            for pathComponent in path.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(pathComponent), isDirectory: true).appendingPathComponent("node")
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    candidates.append(candidate)
                }
            }
        }

        let fallbackPaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/opt/local/bin/node",
            "/usr/bin/node"
        ]

        candidates.append(contentsOf: fallbackPaths
            .filter { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) })

        for candidate in uniqueURLs(candidates) {
            if nodeIsRunnable(at: candidate) {
                return candidate
            }
        }

        throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Node.js is unavailable, so QuickSnap could not run the Obsidian Clipper helper."
        ])
    }

    private static func bundledNodeURL() -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent(helperRuntimeDirectoryName, isDirectory: true)
            .appendingPathComponent("node")
    }

    private static func nodeIsRunnable(at url: URL) -> Bool {
        let process = Process()
        process.executableURL = url
        process.arguments = ["--version"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var ordered: [URL] = []
        for url in urls {
            if seen.insert(url.path).inserted {
                ordered.append(url)
            }
        }
        return ordered
    }
}
