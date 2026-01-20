import AuthenticationServices
import SwiftUI

/// A styled Sign in with Apple button that matches Apple's HIG.
struct AppleSignInButton: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                request.requestedScopes = [.email, .fullName]
            },
            onCompletion: { _ in
                // We handle the actual sign-in through AppleSignInService
                // This completion is just for the button's internal state
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(10)
        .onTapGesture {
            Task {
                await authViewModel.signInWithApple()
            }
        }
        .allowsHitTesting(!authViewModel.isLoading)
        .opacity(authViewModel.isLoading ? 0.6 : 1.0)
    }
}

#Preview {
    AppleSignInButton()
        .padding()
        .environmentObject(AuthViewModel())
}
