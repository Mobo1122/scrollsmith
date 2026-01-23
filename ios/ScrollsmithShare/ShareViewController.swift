import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main entry point for the Share Extension.
///
/// Receives shared content from other apps and presents a SwiftUI view
/// for the user to confirm saving the video to Scrollsmith.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the shared model container
        let container = SharedModelContainer.shared

        // Create the SwiftUI view
        let shareView = ShareExtensionView(
            extensionContext: extensionContext
        )
        .modelContainer(container)

        // Embed in UIHostingController
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }
}
