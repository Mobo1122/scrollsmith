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
        decoder.dateDecodingStrategy = .flexibleISO8601
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
        decoder.dateDecodingStrategy = .flexibleISO8601
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

    /// Generates AI summary for a video.
    ///
    /// - Parameters:
    ///   - videoId: The video ID to summarize
    ///   - format: Summary format (bullets, steps, cards). Defaults to bullets.
    /// - Returns: The summarize response with generated content
    func summarizeVideo(
        videoId: UUID,
        format: String = "bullets"
    ) async throws -> SummarizeResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(videoId.uuidString.lowercased())/summarize") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["format": format]
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
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode(SummarizeResponse.self, from: data)
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
        decoder.dateDecodingStrategy = .flexibleISO8601

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
        decoder.dateDecodingStrategy = .flexibleISO8601
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
        decoder.dateDecodingStrategy = .flexibleISO8601
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

    /// Fetches videos, optionally filtered by Playbook, tag, or uncategorized status.
    func getVideos(playbookId: UUID? = nil, uncategorized: Bool = false, tag: String? = nil) async throws -> [VideoDTO] {
        var urlString = "\(baseURL)/api/v1/videos"
        var queryItems: [String] = []

        if let playbookId = playbookId {
            queryItems.append("playbook_id=\(playbookId.uuidString.lowercased())")
        }
        if uncategorized {
            queryItems.append("uncategorized=true")
        }
        if let tag = tag, let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            queryItems.append("tag=\(encoded)")
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
        decoder.dateDecodingStrategy = .flexibleISO8601

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
        decoder.dateDecodingStrategy = .flexibleISO8601

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

    /// Deletes a single video (soft delete - moves to Recently Deleted).
    /// Video will be permanently deleted after 30 days.
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

    /// Gets soft-deleted videos (Recently Deleted).
    /// Only returns videos deleted within the last 30 days.
    func getDeletedVideos() async throws -> [VideoDTO] {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos?deleted=true") else {
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
        decoder.dateDecodingStrategy = .flexibleISO8601

        let listResponse = try decoder.decode(VideoListResponse.self, from: data)
        return listResponse.videos
    }

    /// Restores a soft-deleted video from Recently Deleted.
    func restoreVideo(id: UUID) async throws -> VideoDTO {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(id.uuidString.lowercased())/restore") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"

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
        decoder.dateDecodingStrategy = .flexibleISO8601

        return try decoder.decode(VideoDTO.self, from: data)
    }

    /// Permanently deletes a video immediately (bypasses 30-day retention).
    /// This is irreversible.
    func permanentlyDeleteVideo(id: UUID) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(id.uuidString.lowercased())/permanent") else {
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

    /// Gets all tags with video counts, sorted by most used first.
    func getTags() async throws -> [TagDTO] {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/tags") else {
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
        decoder.dateDecodingStrategy = .flexibleISO8601

        return try decoder.decode([TagDTO].self, from: data)
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

    // MARK: - Subscriptions

    /// Fetches current user's usage and subscription status.
    ///
    /// Returns videos used this month, limit, and whether user can create more videos.
    /// Backend will implement GET /api/v1/subscriptions/usage in Phase 8.
    func fetchUsage() async throws -> UsageResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/subscriptions/usage") else {
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
        return try decoder.decode(UsageResponse.self, from: data)
    }

    // MARK: - Habits

    /// Extracts habit suggestions from a video transcript (Pro only).
    ///
    /// - Parameter videoId: The video to extract habits from
    /// - Returns: 1-3 habit suggestions from Claude API
    /// - Throws: APIError.proRequired if user is not Pro, other APIError types
    func extractHabits(videoId: UUID) async throws -> HabitExtractionResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits/videos/\(videoId.uuidString.lowercased())/extract") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle Pro-required error specially for UI to show paywall
        if httpResponse.statusCode == 403 {
            throw APIError.proRequired
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(HabitExtractionResponse.self, from: data)
    }

    /// Creates a habit from a selected suggestion.
    ///
    /// - Parameters:
    ///   - videoId: Source video ID
    ///   - title: Habit title (from suggestion or modified)
    ///   - frequency: Selected frequency
    /// - Returns: Created habit DTO
    func createHabit(videoId: UUID, title: String, frequency: HabitFrequency) async throws -> HabitDTO {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = HabitCreateRequest(videoId: videoId, title: title, frequency: frequency)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            throw APIError.proRequired
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode(HabitDTO.self, from: data)
    }

    /// Fetches all habits for the current user.
    func getHabits() async throws -> [HabitDTO] {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits") else {
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
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode([HabitDTO].self, from: data)
    }

    /// Completes a habit for today.
    ///
    /// - Parameters:
    ///   - habitId: The habit to complete
    ///   - timezone: User's timezone for accurate day boundary calculation
    /// - Returns: Completion response with updated streak info
    func completeHabit(habitId: UUID, timezone: String = TimeZone.current.identifier) async throws -> HabitCompletionResponse {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits/\(habitId.uuidString.lowercased())/complete") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = HabitCompletionRequest(timezone: timezone)
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
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode(HabitCompletionResponse.self, from: data)
    }

    /// Updates a habit (partial update).
    ///
    /// - Parameters:
    ///   - habitId: The habit to update
    ///   - request: Partial update request (only non-nil fields are updated)
    /// - Returns: Updated habit DTO
    func updateHabit(habitId: UUID, request: HabitUpdateRequest) async throws -> HabitDTO {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits/\(habitId.uuidString.lowercased())") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getAccessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode(HabitDTO.self, from: data)
    }

    /// Deletes a habit.
    ///
    /// - Parameter habitId: The habit to delete
    func deleteHabit(habitId: UUID) async throws {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits/\(habitId.uuidString.lowercased())") else {
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

    /// Gets habit completions for calendar display.
    ///
    /// - Parameter habitId: The habit to get completions for
    /// - Returns: Array of completion responses
    func getHabitCompletions(habitId: UUID) async throws -> [HabitCompletionResponse] {
        guard let endpoint = URL(string: "\(baseURL)/api/v1/habits/\(habitId.uuidString.lowercased())/completions") else {
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
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode([HabitCompletionResponse].self, from: data)
    }

    // MARK: - Private

    private func getAccessToken() async -> String? {
        let token = await KeychainService.shared.getAccessToken()
        if token == nil {
            print("DEBUG APIClient: No access token found - user may not be logged in")
        } else {
            print("DEBUG APIClient: Access token found (length: \(token!.count))")
        }
        return token
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unauthorized
    case proRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (HTTP \(code))"
        case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
        case .unauthorized: return "Please log in again"
        case .proRequired: return "This feature requires a Pro subscription"
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

struct SummarizeResponse: Decodable {
    let videoId: UUID
    let format: String
    let cached: Bool
    let tags: [String]?
    // Note: `summary` field is ignored - it's a dynamic dict we don't need
    // The summary gets saved to the video record and fetched via getVideos()

    enum CodingKeys: String, CodingKey {
        case videoId, format, cached, tags
        // `summary` intentionally omitted - ignored during decoding
    }
}

// MARK: - Playbook DTOs

struct PlaybookDTO: Codable, Identifiable, Hashable {
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

struct VideoDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let sourceUrl: String?
    let thumbnailUrl: String?
    let summaryBullets: String?
    let summarySteps: String?       // Pro tier: JSON string of StepChecklist
    let summaryCards: String?       // Pro tier: JSON string of CardsSummary
    let userEditedSummary: Bool?    // Indicates user edited the summary
    let tags: [String]?
    let createdAt: Date
    let deletedAt: Date?            // Timestamp when video was soft deleted

    /// Whether this video is soft-deleted (in Recently Deleted)
    var isDeleted: Bool {
        deletedAt != nil
    }

    /// Number of days remaining before permanent deletion (max 30)
    var daysUntilPermanentDeletion: Int? {
        guard let deletedAt = deletedAt else { return nil }
        let daysSinceDeletion = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        return max(0, 30 - daysSinceDeletion)
    }

    // Memberwise init for Previews
    init(
        id: UUID,
        sourceUrl: String? = nil,
        thumbnailUrl: String? = nil,
        summaryBullets: String? = nil,
        summarySteps: String? = nil,
        summaryCards: String? = nil,
        userEditedSummary: Bool? = nil,
        tags: [String]? = nil,
        createdAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.sourceUrl = sourceUrl
        self.thumbnailUrl = thumbnailUrl
        self.summaryBullets = summaryBullets
        self.summarySteps = summarySteps
        self.summaryCards = summaryCards
        self.userEditedSummary = userEditedSummary
        self.tags = tags
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

// MARK: - VideoDTO Parsing Helpers

/// Backend BulletSummary structure
private struct BulletSummaryPayload: Decodable {
    let bullets: [String]
    let tags: [String]?
}

extension VideoDTO {
    /// Parses summary_bullets JSON string into array of strings.
    /// Backend stores as {"bullets": [...], "tags": [...]}
    var parsedBullets: [String]? {
        guard let json = summaryBullets else { return nil }
        // Try new format first: {"bullets": [...], "tags": [...]}
        if let payload = try? JSONDecoder().decode(BulletSummaryPayload.self, from: Data(json.utf8)) {
            return payload.bullets
        }
        // Fallback to legacy format: ["bullet1", "bullet2"]
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
    let thumbnailUrl: String?
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
    /// Backend stores as {"bullets": [...], "tags": [...]}
    var parsedBullets: [String]? {
        guard let json = summaryBullets else { return nil }
        // Try new format first: {"bullets": [...], "tags": [...]}
        if let payload = try? JSONDecoder().decode(BulletSummaryPayload.self, from: Data(json.utf8)) {
            return payload.bullets
        }
        // Fallback to legacy format: ["bullet1", "bullet2"]
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

// MARK: - Flexible Date Decoder

extension JSONDecoder {
    /// Creates a decoder configured for API responses with flexible date parsing.
    static func flexibleAPIDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .flexibleISO8601
        return decoder
    }
}

extension JSONDecoder.DateDecodingStrategy {
    /// Flexible ISO8601 date decoding that handles multiple formats.
    static var flexibleISO8601: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds (Python/FastAPI default)
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractional.date(from: dateString) {
                return date
            }

            // Try standard ISO8601
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try without timezone (assume UTC)
            let noTZFormatter = DateFormatter()
            noTZFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            noTZFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = noTZFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }
}
