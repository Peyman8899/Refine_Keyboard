import Foundation

enum RewriteMode: String, CaseIterable {
    case polish       = "Polish"
    case warm         = "Warm"
    case professional = "Professional"
    case shorter      = "Shorter"
    case translate    = "Translate"
    case grammar      = "Grammar"
    case flirty       = "Flirty"
    case street       = "Vibe"
    case funny        = "Funny"
    case custom       = "Custom"
}

struct RewriteRequest: Encodable {
    let text: String
    let mode: String
    let language: String
    let customInstruction: String

    enum CodingKeys: String, CodingKey {
        case text, mode, language
        case customInstruction = "custom_instruction"
    }
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
        case .missingEndpoint:   return "Service not configured"
        case .server(let msg):   return msg
        case .invalidResponse:   return "Service response was invalid"
        }
    }
}

final class RewriteClient {
    func rewrite(text: String, mode: RewriteMode, language: String, customInstruction: String = "") async throws -> String {
        let endpoint = KeyboardSettings.rewriteEndpoint
        guard let url = URL(string: endpoint), !endpoint.isEmpty else {
            throw RewriteClientError.missingEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(KeyboardSettings.appSecret, forHTTPHeaderField: "X-App-Secret")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(
            RewriteRequest(text: text, mode: mode.rawValue, language: language, customInstruction: customInstruction)
        )

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
        case .message(let m): return m
        case .validation:     return "Request was invalid"
        }
    }

    enum Detail: Decodable {
        case message(String), validation
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let m = try? c.decode(String.self) { self = .message(m); return }
            self = .validation
        }
    }
}
