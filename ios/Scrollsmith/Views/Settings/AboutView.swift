import SwiftUI
import MessageUI

/// About screen with legal links, support contact, and app info.
///
/// Displays:
/// - Support email with mail composer
/// - Terms of Service link
/// - Privacy Policy link
/// - App version and build number
struct AboutView: View {
    @State private var showingMailComposer = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var showingMailAlert = false

    private let supportEmail = "hello@scrollsmith.app"
    private let supportSubject = "Scrollsmith Support Request"

    var body: some View {
        List {
            // Support Section
            Section("Support") {
                Button {
                    if MailView.canSendMail {
                        showingMailComposer = true
                    } else {
                        // Fallback: try mailto URL or show alert
                        let subject = supportSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)") {
                            UIApplication.shared.open(url)
                        } else {
                            showingMailAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Label("Contact Support", systemImage: "envelope")
                        Spacer()
                        Text(supportEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Legal Section
            Section("Legal") {
                Button {
                    showingTerms = true
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }

                Button {
                    showingPrivacy = true
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }

            // App Info Section
            Section("App") {
                LabeledContent("Version") {
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }

                LabeledContent("Build") {
                    Text(buildNumber)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About")
                    .font(Typography.title3)
            }
        }
        .sheet(isPresented: $showingMailComposer) {
            MailView(recipient: supportEmail, subject: supportSubject)
        }
        .sheet(isPresented: $showingTerms) {
            LegalDocumentView(documentType: .terms)
        }
        .sheet(isPresented: $showingPrivacy) {
            LegalDocumentView(documentType: .privacy)
        }
        .alert("Email Not Available", isPresented: $showingMailAlert) {
            Button("OK") { }
        } message: {
            Text("Please email \(supportEmail) for support.")
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
