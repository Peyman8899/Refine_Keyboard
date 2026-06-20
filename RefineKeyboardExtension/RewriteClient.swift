import Foundation

enum RewriteMode: String, CaseIterable {
    case polish = "Polish"
    case warm = "Warm"
    case professional = "Professional"
    case shorter = "Shorter"
}

struct RewriteRequest: Encodable {
    let text: String
    let mode: String
    let language: String
}

struct RewriteResponse: Decodable {
    let text: String
}

enum RewriteClientError: LocalizedError {
    case missingEndpoint
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Service not configured"
        case .server(let message):
            return message
        case .invalidResponse:
            return "Service response was invalid"
        }
    }
}

final class RewriteClient {
    func rewrite(text: String, mode: RewriteMode, language: String) async throws -> String {
        let endpoint = KeyboardSettings.rewriteEndpoint
        guard let url = URL(string: endpoint), !endpoint.isEmpty else {
            throw RewriteClientError.missingEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(KeyboardSettings.appSecret, forHTTPHeaderField: "X-App-Secret")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(RewriteRequest(text: text, mode: mode.rawValue, language: language))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewriteClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(RewriteErrorResponse.self, from: data) {
                throw RewriteClientError.server(errorResponse.displayMessage)
            }
            throw RewriteClientError.server("Service error \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(RewriteResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct RewriteErrorResponse: Decodable {
    let detail: Detail

    var displayMessage: String {
        switch detail {
        case .message(let message):
            return message
        case .validation:
            return "Request was invalid"
        }
    }

    enum Detail: Decodable {
        case message(String)
        case validation

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let message = try? container.decode(String.self) {
                self = .message(message)
                return
            }
            self = .validation
        }
    }
}
