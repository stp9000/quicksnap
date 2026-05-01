import CryptoKit
import Foundation
import os

struct CloudAssetStorageConfiguration {
    var isEnabled: Bool
    var endpointURLString: String
    var region: String
    var bucket: String
    var keyPrefix: String
    var accessKeyID: String
    var secretAccessKey: String

    var isUsable: Bool {
        isEnabled &&
            URL(string: endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil &&
            !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum CloudAssetStorageError: Error {
    case invalidConfiguration
    case invalidObjectURL
    case uploadFailed(Int, String)
}

extension CloudAssetStorageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Cloud storage settings are incomplete or invalid."
        case .invalidObjectURL:
            return "QuickSnap could not build the R2 object URL."
        case .uploadFailed(let status, let body):
            let trimmedBody = body
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBody.isEmpty {
                return "R2 returned HTTP \(status)."
            }
            return "R2 returned HTTP \(status): \(String(trimmedBody.prefix(180)))"
        }
    }
}

enum CloudAssetStorageClient {
    private static let logger = Logger(subsystem: "com.quicksnap.app", category: "CloudAssetStorage")

    static func uploadCapture(_ capture: CaptureRecord, configuration: CloudAssetStorageConfiguration) async throws -> URL {
        guard configuration.isUsable,
              let imageData = try? Data(contentsOf: capture.imageURL) else {
            throw CloudAssetStorageError.invalidConfiguration
        }

        return try await uploadCaptureData(imageData, capture: capture, configuration: configuration)
    }

    static func uploadCaptureData(_ imageData: Data, capture: CaptureRecord, configuration: CloudAssetStorageConfiguration) async throws -> URL {
        guard configuration.isUsable else {
            throw CloudAssetStorageError.invalidConfiguration
        }

        let objectKey = objectKey(for: capture, prefix: configuration.keyPrefix)
        let objectURL = try makeObjectURL(
            endpointURLString: configuration.endpointURLString,
            bucket: configuration.bucket,
            objectKey: objectKey
        )

        var request = URLRequest(url: objectURL)
        request.httpMethod = "PUT"
        request.httpBody = imageData
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")

        try sign(
            request: &request,
            payload: imageData,
            accessKeyID: configuration.accessKeyID,
            secretAccessKey: configuration.secretAccessKey,
            region: configuration.region
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("R2 upload failed status=\(status, privacy: .public) url=\(objectURL.redactedForLogging, privacy: .public) body=\(body.prefix(240), privacy: .public)")
            throw CloudAssetStorageError.uploadFailed(status, body)
        }

        logger.info("R2 upload succeeded url=\(objectURL.redactedForLogging, privacy: .public)")
        return objectURL
    }

    static func downloadCapture(_ capture: CaptureRecord, configuration: CloudAssetStorageConfiguration) async throws -> Data {
        guard configuration.isUsable else {
            throw CloudAssetStorageError.invalidConfiguration
        }

        let objectKey = objectKey(for: capture, prefix: configuration.keyPrefix)
        let objectURL = try makeObjectURL(
            endpointURLString: configuration.endpointURLString,
            bucket: configuration.bucket,
            objectKey: objectKey
        )

        var request = URLRequest(url: objectURL)
        request.httpMethod = "GET"

        try sign(
            request: &request,
            payload: Data(),
            accessKeyID: configuration.accessKeyID,
            secretAccessKey: configuration.secretAccessKey,
            region: configuration.region
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CloudAssetStorageError.uploadFailed(status, body)
        }

        return data
    }

    private static func objectKey(for capture: CaptureRecord, prefix: String) -> String {
        let normalizedPrefix = prefix
            .trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        let filename = "\(capture.id).png"
        return normalizedPrefix.isEmpty ? filename : "\(normalizedPrefix)/\(filename)"
    }

    private static func makeObjectURL(endpointURLString: String, bucket: String, objectKey: String) throws -> URL {
        guard let endpoint = URL(string: endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw CloudAssetStorageError.invalidConfiguration
        }

        let safeBucket = bucket.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        let encodedKey = objectKey.split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        let endpointPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathAlreadyIncludesBucket = endpointPath.split(separator: "/").last.map(String.init) == safeBucket
        components.path = [endpointPath, pathAlreadyIncludesBucket ? "" : safeBucket, encodedKey]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/" + components.path

        guard let url = components.url else {
            throw CloudAssetStorageError.invalidObjectURL
        }
        return url
    }

    private static func sign(
        request: inout URLRequest,
        payload: Data,
        accessKeyID: String,
        secretAccessKey: String,
        region: String
    ) throws {
        guard let url = request.url, let host = url.host else {
            throw CloudAssetStorageError.invalidObjectURL
        }

        let timestamp = Date()
        let amzDate = amzDateFormatter.string(from: timestamp)
        let dateStamp = dateStampFormatter.string(from: timestamp)
        let payloadHash = sha256Hex(payload)
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        let headers = canonicalHeaders(from: request)
        let signedHeaders = headers.map(\.name).joined(separator: ";")
        let canonicalHeadersString = headers.map { "\($0.name):\($0.value)\n" }.joined()
        let canonicalURI = url.path.split(separator: "/").map { segment in
            String(segment).addingPercentEncoding(withAllowedCharacters: .awsCanonicalPathAllowed) ?? String(segment)
        }.joined(separator: "/")
        let canonicalQuery = url.query ?? ""
        let canonicalRequest = [
            request.httpMethod ?? "PUT",
            "/" + canonicalURI,
            canonicalQuery,
            canonicalHeadersString,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region.trimmingCharacters(in: .whitespacesAndNewlines))/s3/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hex(Data(canonicalRequest.utf8))
        ].joined(separator: "\n")

        let signingKey = makeSigningKey(
            secretAccessKey: secretAccessKey,
            dateStamp: dateStamp,
            region: region.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let signature = hmacSHA256Hex(Data(stringToSign.utf8), key: signingKey)
        let authorization = "AWS4-HMAC-SHA256 Credential=\(accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines))/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    private static func canonicalHeaders(from request: URLRequest) -> [(name: String, value: String)] {
        (request.allHTTPHeaderFields ?? [:])
            .map { key, value in
                (
                    name: key.lowercased(),
                    value: value
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .split(whereSeparator: \.isWhitespace)
                        .joined(separator: " ")
                )
            }
            .sorted { $0.name < $1.name }
    }

    private static func makeSigningKey(secretAccessKey: String, dateStamp: String, region: String) -> SymmetricKey {
        let dateKey = hmacSHA256(Data(dateStamp.utf8), key: SymmetricKey(data: Data("AWS4\(secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines))".utf8)))
        let dateRegionKey = hmacSHA256(Data(region.utf8), key: SymmetricKey(data: dateKey))
        let dateRegionServiceKey = hmacSHA256(Data("s3".utf8), key: SymmetricKey(data: dateRegionKey))
        let signingKey = hmacSHA256(Data("aws4_request".utf8), key: SymmetricKey(data: dateRegionServiceKey))
        return SymmetricKey(data: signingKey)
    }

    private static func hmacSHA256(_ data: Data, key: SymmetricKey) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }

    private static func hmacSHA256Hex(_ data: Data, key: SymmetricKey) -> String {
        hmacSHA256(data, key: key).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }

    private static let amzDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    private static let dateStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

private extension URL {
    var redactedForLogging: String {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return absoluteString
        }
        components.user = nil
        components.password = nil
        components.query = nil
        return components.string ?? absoluteString
    }
}

private extension CharacterSet {
    static let awsCanonicalPathAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "?")
        return allowed
    }()
}
