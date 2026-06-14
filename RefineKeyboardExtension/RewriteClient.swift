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

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Service not configured"
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
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(RewriteRequest(text: text, mode: mode.rawValue, language: language))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(RewriteResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
