import Foundation
import WebKit

// MARK: - v2 TODO
// This service is DEFERRED TO v2 along with TikTok/Instagram URL support.
// For v1, users should download TikTok/IG videos to their camera roll and upload from there.
//
// TikTok/IG URL → device-side download + WhisperKit transcription requires macOS 14+
// for the WhisperKit toolchain, but the dev machine is currently on macOS 13.
//
// TODO v2: Enable this service once dev environment is on macOS 14+:
// 1. Uncomment TikTok/IG URL handling in URLInputView and CaptureView
// 2. Update TranscriptionOrchestrator to use this for TikTok/IG URLs
// 3. Add WhisperKit integration for on-device transcription

/// Downloads media from social media URLs (TikTok, Instagram).
///
/// **DEFERRED TO v2** - TikTok/Instagram URL support not used in v1.
///
/// Extracts the actual video URL from the page and downloads to local storage.
/// Uses a headless WKWebView to handle JavaScript-rendered content.
@MainActor
class MediaDownloadService: NSObject, ObservableObject {

    static let shared = MediaDownloadService()

    /// Download progress (0.0 to 1.0).
    @Published private(set) var downloadProgress: Double = 0

    /// Current download state.
    @Published private(set) var state: DownloadState = .idle

    enum DownloadState: Equatable {
        case idle
        case resolvingURL
        case downloading
        case completed
        case failed(message: String)
    }

    /// Temp directory for downloaded media.
    private static let mediaTempDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("media_downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var webView: WKWebView?
    private var downloadTask: URLSessionDownloadTask?
    private var urlContinuation: CheckedContinuation<URL, Error>?

    private override init() {
        super.init()
    }

    /// Downloads media from a social media URL.
    ///
    /// - Parameter url: TikTok or Instagram video URL.
    /// - Returns: Local file URL of the downloaded video.
    /// - Throws: `MediaDownloadError` if download fails.
    func downloadMedia(from url: URL) async throws -> URL {
        state = .resolvingURL
        downloadProgress = 0

        // Resolve short URLs first
        let resolvedURL = try await resolveURL(url)

        // Extract the actual media URL
        let mediaURL = try await extractMediaURL(from: resolvedURL)

        // Download the media file
        state = .downloading
        let localURL = try await downloadFile(from: mediaURL)

        state = .completed
        downloadProgress = 1.0

        return localURL
    }

    /// Resolves short URLs (vm.tiktok.com, etc.) to full URLs.
    ///
    /// - Parameter url: Potentially shortened URL.
    /// - Returns: Resolved full URL.
    func resolveURL(_ url: URL) async throws -> URL {
        // Check if it's already a full URL
        let host = url.host?.lowercased() ?? ""
        if host.contains("tiktok.com") && !host.contains("vm.tiktok.com") {
            return url
        }
        if host.contains("instagram.com") {
            return url
        }

        // Follow redirects to get the final URL
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           let location = httpResponse.url {
            return location
        }

        return url
    }

    /// Extracts the actual media URL from a social media page.
    ///
    /// Uses WKWebView to render the page and extract video source URLs.
    private func extractMediaURL(from pageURL: URL) async throws -> URL {
        // First try the simple HTML parsing approach
        if let mediaURL = try? await extractMediaURLFromHTML(pageURL) {
            return mediaURL
        }

        // Fall back to WebView extraction for JS-rendered content
        return try await extractMediaURLFromWebView(pageURL)
    }

    /// Attempts to extract media URL by parsing HTML directly.
    private func extractMediaURLFromHTML(_ pageURL: URL) async throws -> URL {
        var request = URLRequest(url: pageURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw MediaDownloadError.invalidResponse
        }

        // Try to find video URL in meta tags or JSON-LD
        let patterns = [
            // Open Graph video tag
            #"<meta[^>]+property=[\"']og:video[\"'][^>]+content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:video[\"']"#,
            // Video source in JSON
            #"\"playAddr\"[:\s]+[\"']([^\"']+)[\"']"#,
            #"\"video_url\"[:\s]+[\"']([^\"']+)[\"']"#,
            #"\"downloadAddr\"[:\s]+[\"']([^\"']+)[\"']"#,
            // Instagram specific
            #"\"video_url\"[:\s]*\"([^\"]+)\""#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                var urlString = String(html[range])
                // Unescape unicode
                urlString = urlString.replacingOccurrences(of: "\\u002F", with: "/")
                urlString = urlString.replacingOccurrences(of: "\\/", with: "/")

                if let url = URL(string: urlString), url.scheme == "https" || url.scheme == "http" {
                    return url
                }
            }
        }

        throw MediaDownloadError.mediaURLNotFound
    }

    /// Extracts media URL using WKWebView for JS-rendered content.
    private func extractMediaURLFromWebView(_ pageURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.urlContinuation = continuation

            // Create WebView configuration
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []

            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView

            // Load the page
            let request = URLRequest(url: pageURL)
            webView.load(request)

            // Timeout after 15 seconds
            Task {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                if self.urlContinuation != nil {
                    self.urlContinuation?.resume(throwing: MediaDownloadError.timeout)
                    self.urlContinuation = nil
                    self.webView = nil
                }
            }
        }
    }

    /// Injects JavaScript to find video URLs in the page.
    private func extractVideoURLsFromPage() {
        let javascript = """
        (function() {
            var videos = document.querySelectorAll('video');
            var urls = [];
            videos.forEach(function(v) {
                if (v.src) urls.push(v.src);
                var sources = v.querySelectorAll('source');
                sources.forEach(function(s) {
                    if (s.src) urls.push(s.src);
                });
            });
            return urls.join('|||');
        })();
        """

        webView?.evaluateJavaScript(javascript) { [weak self] result, error in
            guard let self = self, let continuation = self.urlContinuation else { return }

            if let urlString = result as? String, !urlString.isEmpty {
                let urls = urlString.components(separatedBy: "|||")
                if let firstURL = urls.first, let url = URL(string: firstURL) {
                    continuation.resume(returning: url)
                    self.urlContinuation = nil
                    self.webView = nil
                    return
                }
            }

            continuation.resume(throwing: MediaDownloadError.mediaURLNotFound)
            self.urlContinuation = nil
            self.webView = nil
        }
    }

    /// Downloads a file from URL to local storage.
    private func downloadFile(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MediaDownloadError.downloadFailed
        }

        // Determine file extension from content type
        let contentType = httpResponse.mimeType ?? "video/mp4"
        let ext = contentType.contains("mp4") ? "mp4" : "mov"

        // Move to our temp directory
        let destURL = Self.mediaTempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        try FileManager.default.moveItem(at: tempURL, to: destURL)

        return destURL
    }

    /// Cleans up a downloaded media file.
    func cleanup(mediaURL: URL) {
        try? FileManager.default.removeItem(at: mediaURL)
    }

    /// Cleans up all downloaded media files.
    func cleanupAll() {
        try? FileManager.default.removeItem(at: Self.mediaTempDir)
        try? FileManager.default.createDirectory(at: Self.mediaTempDir, withIntermediateDirectories: true)
    }

    /// Resets the service state.
    func reset() {
        state = .idle
        downloadProgress = 0
        downloadTask?.cancel()
        downloadTask = nil
        webView = nil
        urlContinuation = nil
    }
}

// MARK: - WKNavigationDelegate

extension MediaDownloadService: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // Wait a moment for JS to render
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            extractVideoURLsFromPage()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            urlContinuation?.resume(throwing: MediaDownloadError.pageLoadFailed(error))
            urlContinuation = nil
            self.webView = nil
        }
    }
}

/// Errors that can occur during media download.
enum MediaDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case mediaURLNotFound
    case pageLoadFailed(Error)
    case downloadFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid media URL"
        case .invalidResponse:
            return "Could not parse page content"
        case .mediaURLNotFound:
            return "Could not find video in page. The video may be private or unavailable."
        case .pageLoadFailed(let error):
            return "Failed to load page: \(error.localizedDescription)"
        case .downloadFailed:
            return "Failed to download video"
        case .timeout:
            return "Download timed out. Please try again."
        }
    }
}
