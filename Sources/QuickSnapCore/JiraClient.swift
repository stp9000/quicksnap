import Foundation

enum JiraClientError: Error {
    case invalidDomain
    case badResponse
    case apiError(String)
}

enum JiraClient {
    struct CreatedIssue {
        let key: String
        let browseURL: URL
    }

    static func createIssue(
        domain: String,
        email: String,
        token: String,
        projectKey: String,
        issueType: String,
        summary: String,
        description: String
    ) async throws -> CreatedIssue {
        let normalizedDomain = normalizedDomain(domain)
        guard let issueURL = URL(string: "https://\(normalizedDomain)/rest/api/3/issue") else {
            throw JiraClientError.invalidDomain
        }

        let body = CreateIssueRequest(
            fields: .init(
                project: .init(key: projectKey),
                summary: summary,
                issueType: .init(name: issueType),
                description: atlasDocument(from: description)
            )
        )

        var request = URLRequest(url: issueURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(basicAuth(email: email, token: token))", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JiraClientError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw apiError(from: data) ?? JiraClientError.badResponse
        }

        let payload = try JSONDecoder().decode(CreateIssueResponse.self, from: data)
        guard let browseURL = URL(string: "https://\(normalizedDomain)/browse/\(payload.key)") else {
            throw JiraClientError.invalidDomain
        }
        return CreatedIssue(key: payload.key, browseURL: browseURL)
    }

    static func attachFile(
        domain: String,
        email: String,
        token: String,
        issueKey: String,
        imageData: Data,
        filename: String
    ) async throws {
        let normalizedDomain = normalizedDomain(domain)
        guard let attachmentURL = URL(string: "https://\(normalizedDomain)/rest/api/3/issue/\(issueKey)/attachments") else {
            throw JiraClientError.invalidDomain
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: attachmentURL)
        request.httpMethod = "POST"
        request.setValue("Basic \(basicAuth(email: email, token: token))", forHTTPHeaderField: "Authorization")
        request.setValue("no-check", forHTTPHeaderField: "X-Atlassian-Token")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JiraClientError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw apiError(from: data) ?? JiraClientError.badResponse
        }
    }

    private static func normalizedDomain(_ domain: String) -> String {
        domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func basicAuth(email: String, token: String) -> String {
        Data("\(email):\(token)".utf8).base64EncodedString()
    }

    private static func atlasDocument(from text: String) -> AtlasDoc {
        let paragraphs = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map { line in
                AtlasBlock(
                    type: "paragraph",
                    content: line.isEmpty ? [] : [AtlasText(type: "text", text: line)]
                )
            }
        return AtlasDoc(version: 1, type: "doc", content: paragraphs)
    }

    private static func apiError(from data: Data) -> JiraClientError? {
        if let payload = try? JSONDecoder().decode(JiraErrorResponse.self, from: data) {
            let joined = (payload.errorMessages + payload.errors.values.map { $0 })
                .joined(separator: "\n")
            if !joined.isEmpty {
                return .apiError(joined)
            }
        }
        return nil
    }
}

private struct CreateIssueRequest: Encodable {
    let fields: Fields

    struct Fields: Encodable {
        let project: Project
        let summary: String
        let issueType: IssueType
        let description: AtlasDoc

        enum CodingKeys: String, CodingKey {
            case project
            case summary
            case issueType = "issuetype"
            case description
        }
    }

    struct Project: Encodable {
        let key: String
    }

    struct IssueType: Encodable {
        let name: String
    }
}

private struct CreateIssueResponse: Decodable {
    let key: String
}

private struct JiraErrorResponse: Decodable {
    let errorMessages: [String]
    let errors: [String: String]
}

private struct AtlasDoc: Encodable {
    let version: Int
    let type: String
    let content: [AtlasBlock]
}

private struct AtlasBlock: Encodable {
    let type: String
    let content: [AtlasText]
}

private struct AtlasText: Encodable {
    let type: String
    let text: String
}
