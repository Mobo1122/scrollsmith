import SwiftUI
import MessageUI

/// UIViewControllerRepresentable wrapper for MFMailComposeViewController.
///
/// Usage:
/// ```
/// .sheet(isPresented: $showMail) {
///     MailView(recipient: "hello@scrollsmith.app", subject: "Support Request")
/// }
/// ```
struct MailView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView

        init(_ parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.dismiss()
        }
    }
}

/// Check if device can send mail (useful for fallback handling).
extension MailView {
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
}
