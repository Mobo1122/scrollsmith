import Foundation

/// API client for communicating with the Scrollsmith backend.
///
/// Uses async/await for all network calls. Automatically includes
/// authentication headers when a token is available.
actor APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "https://backend-production-d73a.up.railway.app") {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    // MARK: - Health

    func healthCheck() async throws -> HealthResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/health") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(HealthResponse.self, from: data)
    }

    // MARK: - Videos

    /// Fetches YouTube captions from the backend.
    ///
    /// - Parameter url: YouTube video URL
    /// - Returns: Response with transcript or error info
    func getYouTubeCaptions(url: String) async throws -> YouTubeCaptionsResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/youtube-captions") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(YouTubeCaptionsResponse.self, from: data)
    }

    /// Creates a video record with transcript from iOS.
    ///
    /// Called after on-device transcription completes.
    /// v2 TODO: This is used for on-device transcription results. Keep for v2.
    func createVideo(
        sourceURL: String,
        platform: String,
        transcript: String,
        title: String? = nil
    ) async throws -> VideoCreateResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = VideoCreateRequest(
            sourceUrl: sourceURL,
            platform: platform,
            transcript: transcript,
            title: title
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VideoCreateResponse.self, from: data)
    }

    /// Uploads an audio file to the backend for server-side transcription.
    ///
    /// v1: Primary path for camera roll uploads. Backend transcribes via Whisper/AssemblyAI.
    func uploadAndTranscribe(
        audioURL: URL,
        platform: String,
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> VideoCreateResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/transcribe") else {
            throw APIError.invalidURL
        }

        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Build multipart form data
        var body = Data()

        // Add platform field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"platform\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(platform)\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Use URLSession delegate for progress tracking
        let (data, response) = try await uploadWithProgress(
            request: request,
            body: body,
            progressHandler: progressHandler
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VideoCreateResponse.self, from: data)
    }

    /// Uploads data with progress tracking.
    private func uploadWithProgress(
        request: URLRequest,
        body: Data,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (Data, URLResponse) {
        var mutableRequest = request
        mutableRequest.httpBody = body

        // For simplicity, use standard data(for:) - progress tracking can be added later
        // TODO: Implement proper upload progress with URLSessionUploadTask
        progressHandler(0.5)  // Simulate mid-progress

        let (data, response) = try await session.data(for: mutableRequest)

        progressHandler(1.0)
        return (data, response)
    }

    // MARK: - Private

    private func getAccessToken() async -> String? {
        await KeychainService.shared.getAccessToken()
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (HTTP \(code))"
        case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
        case .unauthorized: return "Please log in again"
        }
    }
}

// MARK: - Response Types

struct YouTubeCaptionsResponse: Codable {
    let success: Bool
    let videoId: UUID?
    let transcript: String?
    let title: String?
    let transcriptSource: String?
    let error: String?
    let errorType: String?  // rate_limit, no_captions, unavailable, api_error
}

struct VideoCreateRequest: Codable {
    let sourceUrl: String
    let platform: String
    let transcript: String
    let title: String?
}

struct VideoCreateResponse: Codable {
    let id: UUID
    let sourceUrl: String?
    let transcript: String?
    let summaryBullets: String?
    let tags: [String]?
    let createdAt: Date
}
