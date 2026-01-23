# Phase 3 Research: Video Capture (iOS)

**Created:** 2026-01-21
**Goal:** iOS video capture from camera roll, URL paste, and Share Extension with proper permissions

## Requirements Coverage

- CAPT-01: Camera roll upload via PhotosPicker
- CAPT-02: Camera roll permission request
- CAPT-03: Non-video media error
- CAPT-04: Video preview before processing
- CAPT-05: URL paste for TikTok/Instagram/YouTube
- CAPT-06: URL validation
- CAPT-07: Share Extension
- CAPT-11: Upload progress indicator

---

## 1. PhotosPicker (iOS 16+)

### Overview
SwiftUI's `PhotosPicker` provides system-standard photo/video import UI without requiring explicit photo library permissions for limited access.

### Video-Only Selection
```swift
import PhotosUI
import SwiftUI

struct VideoPickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,  // Filter to videos only
            photoLibrary: .shared()
        ) {
            Label("Select Video", systemImage: "video.badge.plus")
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let item = newValue {
                    await loadVideo(from: item)
                }
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem) async {
        // Load as Movie (video file)
        if let movie = try? await item.loadTransferable(type: Movie.self) {
            videoURL = movie.url
        }
    }
}

// Custom Transferable for video
struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // Copy to temp location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
```

### Permission Handling
- **No explicit permission needed** for PhotosPicker - it uses "limited access" mode automatically
- User selects specific items, app only gets access to those
- For CAPT-02, PhotosPicker handles this gracefully - no `PHPhotoLibrary.requestAuthorization()` needed

### Non-Video Error (CAPT-03)
With `.matching: .videos`, non-video items won't appear. But validate anyway:
```swift
guard item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) else {
    throw VideoError.notAVideo
}
```

**Sources:**
- [SwiftUI PhotosPicker - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-select-pictures-using-photospicker)
- [PhotosPicker in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2023/04/25/photospicker-in-swiftui/)

---

## 2. Video Thumbnail Generation (AVFoundation)

### Modern Async Approach (iOS 16+)
```swift
import AVFoundation
import UIKit

func generateThumbnail(from url: URL) async throws -> UIImage {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true  // Correct orientation!
    generator.maximumSize = CGSize(width: 400, height: 400)

    let time = CMTime(seconds: 1, preferredTimescale: 600)

    // iOS 16+ async method
    let (image, _) = try await generator.image(at: time)
    return UIImage(cgImage: image)
}
```

### iOS 18+ Note
`copyCGImage(at:actualTime:)` is deprecated in iOS 18. Use the async method above or:
```swift
// Completion handler version (works on older iOS)
generator.generateCGImageAsynchronously(for: time) { result in
    switch result {
    case .success(let requestedTime, let image, let actualTime):
        // Use image
    case .failure(let requestedTime, let error):
        // Handle error
    }
}
```

### Best Practices
- Always set `appliesPreferredTrackTransform = true` (prevents sideways thumbnails)
- Cache thumbnails to avoid regeneration
- Generate on background queue, display on main

**Sources:**
- [AVAssetImageGenerator - Apple Docs](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator)
- [WWDC22 - Create a more responsive media app](https://developer.apple.com/videos/play/wwdc2022/110379/)

---

## 3. URL Validation (TikTok, Instagram, YouTube)

### Regex Patterns
```swift
struct VideoURLValidator {

    enum Platform {
        case tiktok
        case instagram
        case youtube
        case unknown
    }

    // TikTok patterns
    // Matches: tiktok.com/@user/video/123, vm.tiktok.com/abc, m.tiktok.com/v/123
    static let tiktokPattern = #"""
    (?:https?://)?(?:(?:www|m|vm)\.)?tiktok\.com/(?:@[\w.-]+/video/\d+|v/\d+|[\w]+)
    """#

    // Instagram patterns
    // Matches: instagram.com/p/ABC123, instagram.com/reel/ABC123
    static let instagramPattern = #"""
    (?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/[\w-]+/?
    """#

    // YouTube patterns
    // Matches: youtube.com/watch?v=, youtu.be/, youtube.com/shorts/
    static let youtubePattern = #"""
    (?:https?://)?(?:(?:www|m)\.)?(?:youtube\.com/(?:watch\?v=|shorts/)|youtu\.be/)[\w-]+
    """#

    static func validate(_ urlString: String) -> (isValid: Bool, platform: Platform) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.range(of: tiktokPattern, options: .regularExpression) != nil {
            return (true, .tiktok)
        }
        if trimmed.range(of: instagramPattern, options: .regularExpression) != nil {
            return (true, .instagram)
        }
        if trimmed.range(of: youtubePattern, options: .regularExpression) != nil {
            return (true, .youtube)
        }

        return (false, .unknown)
    }

    static func extractVideoId(_ urlString: String, platform: Platform) -> String? {
        // Platform-specific ID extraction
        switch platform {
        case .youtube:
            // Extract v= parameter or path component
            if let url = URL(string: urlString) {
                if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                    return queryItems.first(where: { $0.name == "v" })?.value
                }
                // youtu.be/ID or shorts/ID
                return url.lastPathComponent
            }
        case .tiktok:
            // Extract video ID from path
            if let url = URL(string: urlString) {
                let components = url.pathComponents
                if let videoIndex = components.firstIndex(of: "video"),
                   videoIndex + 1 < components.count {
                    return components[videoIndex + 1]
                }
            }
        case .instagram:
            // Extract post ID
            if let url = URL(string: urlString) {
                return url.pathComponents.last
            }
        case .unknown:
            return nil
        }
        return nil
    }
}
```

**Sources:**
- [Validating Social Media URLs in Swift - Tokopedia Engineering](https://medium.com/tokopedia-engineering/validating-social-media-urls-in-swift-5df900b7bcad)
- [regex101 TikTok patterns](https://regex101.com/library/D2hDie)

---

## 4. Share Extension with SwiftData

### App Group Setup

1. **Create App Group** in Apple Developer Portal
   - Format: `group.com.yourteam.scrollsmith`

2. **Add Capability to Both Targets**
   - Main app target → Signing & Capabilities → + App Groups
   - Share Extension target → Same process

3. **Shared ModelContainer Configuration**
```swift
// Shared/SharedModelContainer.swift
import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.yourteam.scrollsmith"

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PendingUpload.self,
            // Other shared models...
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupIdentifier)
        )

        return try! ModelContainer(for: schema, configurations: [config])
    }()
}
```

### Share Extension Target Setup

1. File → New → Target → Share Extension
2. Name it "ScrollsmithShare"
3. Add App Group capability
4. Add SwiftData models to share extension target membership

### ShareViewController with SwiftUI
```swift
// ShareExtension/ShareViewController.swift
import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let container = SharedModelContainer.sharedModelContainer

        let shareView = ShareExtensionView(
            extensionContext: extensionContext
        )
        .modelContainer(container)

        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }
}
```

### ShareExtensionView
```swift
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?
    @Environment(\.modelContext) private var modelContext
    @State private var sharedURL: URL?
    @State private var isProcessing = false
    @State private var savedSuccessfully = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    ProgressView("Saving...")
                } else if savedSuccessfully {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("Saved to Scrollsmith")
                } else {
                    Text("Save this video?")
                    if let url = sharedURL {
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .navigationTitle("Scrollsmith")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        extensionContext?.cancelRequest(withError: NSError(domain: "user_cancelled", code: 0))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVideo()
                    }
                    .disabled(sharedURL == nil || isProcessing)
                }
            }
        }
        .task {
            await extractSharedContent()
        }
    }

    private func extractSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Check for URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        await MainActor.run {
                            sharedURL = url
                        }
                        return
                    }
                }

                // Check for plain text (URL as string)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                       let url = URL(string: text) {
                        await MainActor.run {
                            sharedURL = url
                        }
                        return
                    }
                }
            }
        }
    }

    private func saveVideo() {
        guard let url = sharedURL else { return }
        isProcessing = true

        // Create pending upload for main app to process
        let pendingUpload = PendingUpload(
            sourceURL: url.absoluteString,
            createdAt: Date()
        )
        modelContext.insert(pendingUpload)

        do {
            try modelContext.save()
            savedSuccessfully = true

            // Dismiss after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                extensionContext?.completeRequest(returningItems: nil)
            }
        } catch {
            isProcessing = false
            // Handle error
        }
    }
}
```

### PendingUpload Model (Shared)
```swift
import SwiftData
import Foundation

@Model
final class PendingUpload {
    var id: UUID
    var sourceURL: String
    var createdAt: Date
    var processedAt: Date?
    var status: String  // "pending", "processing", "completed", "failed"

    init(sourceURL: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.status = "pending"
    }
}
```

### Main App Processing Queue
```swift
// In main app on launch
func processPendingUploads() async {
    let descriptor = FetchDescriptor<PendingUpload>(
        predicate: #Predicate { $0.status == "pending" }
    )

    do {
        let pending = try modelContext.fetch(descriptor)
        for upload in pending {
            upload.status = "processing"
            try modelContext.save()

            // Process the upload...
            await processUpload(upload)

            upload.status = "completed"
            upload.processedAt = Date()
            try modelContext.save()
        }
    } catch {
        // Handle error
    }
}
```

**Sources:**
- [iOS Share Extension with SwiftUI and SwiftData - Sam Merrell](https://www.merrell.dev/ios-share-extension-with-swiftui-and-swiftdata/)
- [App Groups - Fleksy](https://www.fleksy.com/blog/communicating-between-an-ios-app-extensions-using-app-groups/)
- [SwiftData and App Extensions - Apple Forums](https://developer.apple.com/forums/thread/732986)

---

## 5. Upload Progress UI

### ProgressView with Percentage
```swift
struct UploadProgressView: View {
    @Binding var progress: Double  // 0.0 to 1.0
    @Binding var status: UploadStatus

    enum UploadStatus {
        case idle
        case uploading
        case processing
        case completed
        case failed(Error)
    }

    var body: some View {
        VStack(spacing: 16) {
            switch status {
            case .idle:
                EmptyView()

            case .uploading:
                ProgressView(value: progress) {
                    Text("Uploading...")
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                }
                .progressViewStyle(.linear)

            case .processing:
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Processing video...")
                    .font(.caption)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                Text("Complete!")

            case .failed(let error):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.title)
                Text(error.localizedDescription)
                    .font(.caption)
                Button("Retry") {
                    // Retry action
                }
            }
        }
        .padding()
    }
}
```

### URLSession Upload with Progress
```swift
func uploadVideo(fileURL: URL, to endpoint: URL) async throws -> (Data, URLResponse) {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"

    // Use upload task with delegate for progress
    let (data, response) = try await URLSession.shared.upload(
        for: request,
        fromFile: fileURL,
        delegate: uploadDelegate
    )

    return (data, response)
}

// Progress delegate
class UploadDelegate: NSObject, URLSessionTaskDelegate {
    var progressHandler: ((Double) -> Void)?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }
}
```

---

## 6. File Management Best Practices

### Temporary Video Storage
```swift
enum VideoFileManager {

    static let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("video_uploads", isDirectory: true)

    static func setup() throws {
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    static func saveTempVideo(from sourceURL: URL) throws -> URL {
        let filename = UUID().uuidString + "." + sourceURL.pathExtension
        let destURL = tempDirectory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    static func cleanup(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func cleanupAll() {
        try? FileManager.default.removeItem(at: tempDirectory)
        try? setup()
    }
}
```

### Memory Considerations
- Videos can be large (100MB+)
- Never load entire video into memory
- Use file URLs and streaming
- Clean up temp files after upload completes or fails

---

## 7. Recommended Architecture

### Plan Structure (7 Plans)

1. **03-01: PhotosPicker Integration**
   - VideoPickerView with `.videos` filter
   - Movie Transferable type
   - Temp file management

2. **03-02: Video Preview UI**
   - Thumbnail generation with AVAssetImageGenerator
   - Preview card component
   - Confirmation before upload

3. **03-03: URL Input Validation**
   - URLInputView with TextField
   - Regex validation for TikTok/IG/YouTube
   - Platform detection and display

4. **03-04: Share Extension Target**
   - Create ScrollsmithShare target
   - App Group configuration
   - Basic ShareViewController

5. **03-05: Shared SwiftData Container**
   - PendingUpload model
   - SharedModelContainer configuration
   - Both targets use same container

6. **03-06: Upload Progress UI**
   - ProgressView component
   - URLSession delegate for progress
   - Error states with retry

7. **03-07: Main App Queue Processing**
   - Process pending uploads on launch
   - Background processing capability
   - Cleanup completed items

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| PhotosPicker over PHPickerViewController | SwiftUI native, simpler API, automatic permission handling |
| Regex over URL parsing library | Simple patterns, no dependency, easy to maintain |
| SwiftData shared container | Native solution, works with App Groups, familiar API |
| File-based video handling | Avoids memory issues with large videos |
| Temp directory for staging | System manages cleanup, isolated from app data |

---

*Research completed: 2026-01-21*
