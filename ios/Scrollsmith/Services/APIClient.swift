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

    // MARK: - Playbooks

    /// Fetches all Playbooks for the current user.
    func getPlaybooks() async throws -> [PlaybookDTO] {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/playbooks") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

        let listResponse = try decoder.decode(PlaybookListResponse.self, from: data)
        return listResponse.playbooks
    }

    /// Creates a new Playbook.
    func createPlaybook(name: String, icon: String? = nil) async throws -> PlaybookDTO {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/playbooks") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = CreatePlaybookRequest(name: name, icon: icon)
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
        return try decoder.decode(PlaybookDTO.self, from: data)
    }

    /// Updates an existing Playbook.
    func updatePlaybook(id: UUID, name: String?, icon: String? = nil) async throws -> PlaybookDTO {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/playbooks/\(id.uuidString.lowercased())") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = UpdatePlaybookRequest(name: name, icon: icon)
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
        return try decoder.decode(PlaybookDTO.self, from: data)
    }

    /// Deletes a Playbook.
    func deletePlaybook(id: UUID) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/playbooks/\(id.uuidString.lowercased())") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Assigns a Video to a Playbook.
    func assignVideoToPlaybook(videoId: UUID, playbookId: UUID) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(videoId.uuidString.lowercased())/playbooks") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["playbook_id": playbookId.uuidString.lowercased()]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Removes a Video from a Playbook.
    func removeVideoFromPlaybook(videoId: UUID, playbookId: UUID) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(videoId.uuidString.lowercased())/playbooks/\(playbookId.uuidString.lowercased())") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Fetches videos, optionally filtered by Playbook or uncategorized.
    func getVideos(playbookId: UUID? = nil, uncategorized: Bool = false) async throws -> [VideoDTO] {
        var urlString = "\(baseURL)/api/v1/videos"
        var queryItems: [String] = []

        if let playbookId = playbookId {
            queryItems.append("playbook_id=\(playbookId.uuidString.lowercased())")
        }
        if uncategorized {
            queryItems.append("uncategorized=true")
        }

        if !queryItems.isEmpty {
            urlString += "?" + queryItems.joined(separator: "&")
        }

        guard let endpoint = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

        let listResponse = try decoder.decode(VideoListResponse.self, from: data)
        return listResponse.videos
    }

    // MARK: - Video Search

    /// Searches videos using full-text search.
    func searchVideos(query: String, playbookId: UUID? = nil) async throws -> [VideoSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }

        var urlString = "\(baseURL)/api/v1/videos/search?q=\(encodedQuery)"

        if let playbookId = playbookId {
            urlString += "&playbook_id=\(playbookId.uuidString.lowercased())"
        }

        guard let endpoint = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

        let searchResponse = try decoder.decode(VideoSearchResponse.self, from: data)
        return searchResponse.videos
    }

    // MARK: - Bulk Operations

    /// Deletes multiple videos.
    func bulkDeleteVideos(ids: [UUID]) async throws -> BulkDeleteResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/bulk-delete") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["video_ids": ids.map { $0.uuidString.lowercased() }]
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
        return try decoder.decode(BulkDeleteResponse.self, from: data)
    }

    /// Moves multiple videos to a Playbook.
    func bulkMoveVideos(ids: [UUID], to playbookId: UUID) async throws -> BulkMoveResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/bulk-move") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "video_ids": ids.map { $0.uuidString.lowercased() },
            "playbook_id": playbookId.uuidString.lowercased()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BulkMoveResponse.self, from: data)
    }

    /// Adds multiple videos to Favorites.
    func bulkAddToFavorites(ids: [UUID]) async throws -> BulkMoveResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/bulk-add-to-favorites") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["video_ids": ids.map { $0.uuidString.lowercased() }]
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
        return try decoder.decode(BulkMoveResponse.self, from: data)
    }

    // MARK: - Video CRUD

    /// Deletes a single video.
    func deleteVideo(id: UUID) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(id.uuidString.lowercased())") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Updates tags for a video.
    func updateVideoTags(videoId: UUID, tags: [String]) async throws -> UpdateTagsResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(videoId.uuidString.lowercased())/tags") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = UpdateTagsRequest(tags: tags)
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
        return try decoder.decode(UpdateTagsResponse.self, from: data)
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

// MARK: - Playbook DTOs

struct PlaybookDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let icon: String?
    let isSystem: Bool
    let videoCount: Int
    let createdAt: Date
    let updatedAt: Date
}

struct PlaybookListResponse: Codable {
    let playbooks: [PlaybookDTO]
    let total: Int
}

struct CreatePlaybookRequest: Codable {
    let name: String
    let icon: String?
}

struct UpdatePlaybookRequest: Codable {
    let name: String?
    let icon: String?
}

// MARK: - Video DTOs

struct VideoDTO: Codable, Identifiable {
    let id: UUID
    let sourceUrl: String?
    let summaryBullets: String?
    let summarySteps: String?       // Pro tier: JSON string of StepChecklist
    let summaryCards: String?       // Pro tier: JSON string of CardsSummary
    let userEditedSummary: Bool?    // Indicates user edited the summary
    let tags: [String]?
    let createdAt: Date
}

// MARK: - VideoDTO Parsing Helpers

extension VideoDTO {
    /// Parses summary_bullets JSON string into array of strings.
    var parsedBullets: [String]? {
        guard let json = summaryBullets else { return nil }
        return try? JSONDecoder().decode([String].self, from: Data(json.utf8))
    }

    /// Parses summary_steps JSON string into StepChecklist.
    var parsedSteps: StepChecklist? {
        guard let json = summarySteps else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(StepChecklist.self, from: Data(json.utf8))
    }

    /// Parses summary_cards JSON string into CardsSummary.
    var parsedCards: CardsSummary? {
        guard let json = summaryCards else { return nil }
        return try? JSONDecoder().decode(CardsSummary.self, from: Data(json.utf8))
    }
}

struct VideoListResponse: Codable {
    let videos: [VideoDTO]
    let total: Int
}

// MARK: - Search DTOs

struct VideoSearchResult: Codable, Identifiable {
    let id: UUID
    let sourceUrl: String?
    let summaryBullets: String?
    let summarySteps: String?       // Pro tier: JSON string of StepChecklist
    let summaryCards: String?       // Pro tier: JSON string of CardsSummary
    let userEditedSummary: Bool?    // Indicates user edited the summary
    let tags: [String]?
    let createdAt: Date
    let rank: Double
    let highlight: String?
}

// MARK: - VideoSearchResult Parsing Helpers

extension VideoSearchResult {
    /// Parses summary_bullets JSON string into array of strings.
    var parsedBullets: [String]? {
        guard let json = summaryBullets else { return nil }
        return try? JSONDecoder().decode([String].self, from: Data(json.utf8))
    }

    /// Parses summary_steps JSON string into StepChecklist.
    var parsedSteps: StepChecklist? {
        guard let json = summarySteps else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(StepChecklist.self, from: Data(json.utf8))
    }

    /// Parses summary_cards JSON string into CardsSummary.
    var parsedCards: CardsSummary? {
        guard let json = summaryCards else { return nil }
        return try? JSONDecoder().decode(CardsSummary.self, from: Data(json.utf8))
    }
}

struct VideoSearchResponse: Codable {
    let videos: [VideoSearchResult]
    let query: String
    let total: Int
}

// MARK: - Bulk Operation DTOs

struct BulkDeleteResponse: Codable {
    let deletedCount: Int
    let videoIds: [UUID]
}

struct BulkMoveResponse: Codable {
    let movedCount: Int
    let playbookId: UUID
    let videoIds: [UUID]
}

// MARK: - Tag Update DTOs

struct UpdateTagsRequest: Codable {
    let tags: [String]
}

struct UpdateTagsResponse: Codable {
    let id: UUID
    let tags: [String]
}
