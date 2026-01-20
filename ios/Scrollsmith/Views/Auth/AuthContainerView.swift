import SwiftUI

/// Container view that switches between login, register, and forgot password screens.
struct AuthContainerView: View {
    @State private var currentScreen: AuthScreen = .login

    enum AuthScreen {
        case login
        case register
        case forgotPassword
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentScreen {
                case .login:
                    LoginView(
                        onSwitchToRegister: {
                            withAnimation {
                                currentScreen = .register
                            }
                        },
                        onForgotPassword: {
                            withAnimation {
                                currentScreen = .forgotPassword
                            }
                        }
                    )

                case .register:
                    RegisterView(
                        onSwitchToLogin: {
                            withAnimation {
                                currentScreen = .login
                            }
                        }
                    )

                case .forgotPassword:
                    ForgotPasswordView(
                        onBack: {
                            withAnimation {
                                currentScreen = .login
                            }
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Scrollsmith")
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    AuthContainerView()
        .environmentObject(AuthViewModel())
}
