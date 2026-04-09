import AppKit
import Foundation

struct BrowserPageSourcePayload {
    let urlString: String
    let pageTitle: String
    let html: String
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

enum BrowserPageSourceResolver {
    private struct BrowserScript {
        let appName: String
        let bundleIdentifier: String
        let source: String
    }

    private static let chromiumAppNames = ["Google Chrome", "Arc", "Brave Browser", "Microsoft Edge"]
    private static let extractionJavaScript = """
    JSON.stringify((() => {
        return {
            url: location.href || "",
            title: document.title || "",
            html: document.documentElement ? document.documentElement.outerHTML : ""
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
        guard !html.isEmpty else { return nil }
        return BrowserPageSourcePayload(urlString: urlString, pageTitle: pageTitle, html: html)
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
    private static let repoRootURL: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

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

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard let json = parsedJSON(from: outputData) else {
            throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorText.isEmpty ? "The Markdown helper returned unreadable output." : errorText
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
        guard let braceIndex = trimmed.lastIndex(of: "{") else {
            return nil
        }

        let candidate = String(trimmed[braceIndex...])
        guard let candidateData = candidate.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: candidateData) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func helperDirectoryURL() throws -> URL {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(helperDirectoryName, isDirectory: true),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
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

        if let bundledNode = Bundle.main.resourceURL?
            .appendingPathComponent("HelperRuntime", isDirectory: true)
            .appendingPathComponent("node"),
           FileManager.default.isExecutableFile(atPath: bundledNode.path) {
            candidates.append(bundledNode)
        }

        for candidate in uniqueURLs(candidates) {
            if nodeIsRunnable(at: candidate) {
                return candidate
            }
        }

        throw NSError(domain: "QuickSnap.ObsidianClipperHelper", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Node.js is unavailable, so QuickSnap could not run the Obsidian Clipper helper."
        ])
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
