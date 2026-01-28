import SwiftUI

/// A styled text field with consistent appearance.
struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(Typography.body)
        .padding(.horizontal, Spacing.md)
        .frame(height: Spacing.inputHeight)
        .background(Theme.Background.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                .stroke(isFocused ? Theme.accent : .clear, lineWidth: 2)
        )
        .focused($isFocused)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Preview

#Preview("Text Fields") {
    VStack(spacing: 16) {
        StyledTextField(placeholder: "Email", text: .constant(""))
        StyledTextField(placeholder: "Password", text: .constant(""), isSecure: true)
        StyledTextField(placeholder: "With text", text: .constant("hello@example.com"))
    }
    .padding()
}
