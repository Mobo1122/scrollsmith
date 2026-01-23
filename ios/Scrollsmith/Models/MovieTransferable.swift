import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A Transferable type for importing video files from PhotosPicker.
///
/// When a user selects a video, this type handles copying the video
/// from the Photos library to the app's temp directory. The URL
/// can then be used for thumbnail generation and upload.
struct MovieTransferable: Transferable {

    /// The local URL where the video was copied.
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // Copy the received file to our temp directory
            let tempURL = VideoFileManager.tempDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)

            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
