import Foundation

/// Manages temporary video files for upload staging.
///
/// Videos selected from camera roll are copied to a temp directory before upload.
/// This allows the app to maintain access to the file even after PhotosPicker dismisses.
enum VideoFileManager {

    static let tempDirectory: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("video_uploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Saves a video to the temp directory with a unique filename.
    /// - Parameter sourceURL: The source video URL to copy.
    /// - Returns: The URL of the copied file in the temp directory.
    static func saveTempVideo(from sourceURL: URL) throws -> URL {
        let filename = UUID().uuidString + "." + sourceURL.pathExtension
        let destURL = tempDirectory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    /// Deletes a single temp video file.
    /// - Parameter url: The URL of the file to delete.
    static func cleanup(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes all temp video files.
    static func cleanupAll() {
        try? FileManager.default.removeItem(at: tempDirectory)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    /// Gets the file size in bytes for a video URL.
    /// - Parameter url: The video file URL.
    /// - Returns: File size in bytes, or nil if unable to determine.
    static func fileSize(for url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }

    /// Formats a byte count into a human-readable string.
    /// - Parameter bytes: The number of bytes.
    /// - Returns: A formatted string like "12.5 MB".
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
