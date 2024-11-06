import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = true

    var completion: (String?) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(showSignUp ? "Sign Up" : "Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .frame(height: 50)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .frame(height: 50)
            }
            .padding(.horizontal, 20)

            Button(action: {
                if showSignUp {
                    session.signUp(email: email, password: password) { message in
                        completion(message)
                        // Post a notification after sign up
                        if message == nil {
                            NotificationCenter.default.post(name: .didSignUp, object: nil)
                        }
                    }
                } else {
                    session.signIn(email: email, password: password) { message in
                        completion(message)
                    }
                }
            }) {
                Text(showSignUp ? "Sign Up" : "Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            let userIdentifier = appleIDCredential.user
                            let fullName = appleIDCredential.fullName
                            let email = appleIDCredential.email
                            
                            session.signInWithApple { message in
                                completion(message)
                            }
                        }
                    case .failure(let error):
                        session.errorMessage = error.localizedDescription
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 45)
            .cornerRadius(10)
            .padding(.horizontal, 20)

            // Add "Continue without an account" button
            Button(action: {
                completion(nil)
            }) {
                Text("Continue without an account")
                    .foregroundColor(.red)
                    .padding(.top, 1)
            }
            .padding(.top, 5)

            // Add the "Forgot Password" button here
            Button(action: {
                session.resetPassword(email: email) { message in
                    completion(message)
                }
            }) {
                Text("Forgot Password?")
                    .foregroundColor(.blue)
                    .padding(.top, 1)
            }
            .padding(.top, 5)

            if let verificationMessage = session.verificationMessage {
                Text(verificationMessage)
                    .foregroundColor(.green)
                    .padding(.top, 10)
            }

            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }

            Button(action: {
                showSignUp.toggle()
            }) {
                Text(showSignUp ? "Have an account? Sign In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
                    .padding(.top, 1)
            }
            .padding(.top, 1)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(.horizontal, 20)
    }
}

extension Notification.Name {
    static let didSignUp = Notification.Name("didSignUp")
}
