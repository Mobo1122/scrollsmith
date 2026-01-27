import SwiftUI

/// Container view for displaying legal documents in a sheet.
///
/// Wraps WebView in a NavigationView with title and Done button.
/// Used for Terms of Service and Privacy Policy display.
struct LegalDocumentView: View {
    enum DocumentType {
        case terms
        case privacy

        var title: String {
            switch self {
            case .terms: return "Terms of Service"
            case .privacy: return "Privacy Policy"
            }
        }

        var path: String {
            switch self {
            case .terms: return "/terms"
            case .privacy: return "/privacy"
            }
        }

        var url: URL {
            // Use Configuration.apiBaseURL for the backend URL
            URL(string: Configuration.apiBaseURL + path)!
        }
    }

    let documentType: DocumentType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            WebView(url: documentType.url)
                .navigationTitle(documentType.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview("Terms") {
    LegalDocumentView(documentType: .terms)
}

#Preview("Privacy") {
    LegalDocumentView(documentType: .privacy)
}
