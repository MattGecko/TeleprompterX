import Combine
import AuthenticationServices
import FirebaseAuth
import Firebase

class SessionStore: NSObject, ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var verificationMessage: String? = nil
    @Published var errorMessage: String? = nil
    
    private var auth: Auth {
        return FirebaseManager.shared.auth
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var appleSignInCompletion: ((String?) -> Void)? // Store the completion handler

    override init() {
        super.init()
        self.isSignedIn = auth.currentUser != nil
        // Observe Firebase authentication state changes
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            self?.isSignedIn = user != nil
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    func signInWithApple(completion: @escaping (String?) -> Void) {
        guard appleSignInCompletion == nil else {
            // Sign-in is already in progress
            completion("Sign-in with Apple is already in progress.")
            return
        }
        
        self.appleSignInCompletion = completion
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signIn(email: String, password: String, completion: @escaping (String?) -> Void) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Error signing in: \(error.localizedDescription)"
                    completion(self?.errorMessage)
                } else {
                    self?.isSignedIn = true
                    completion("Successfully signed in")
                }
            }
        }
    }
    
    func signUp(email: String, password: String, completion: @escaping (String?) -> Void) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Error signing up: \(error.localizedDescription)"
                    completion(self?.errorMessage)
                } else {
                    self?.verificationMessage = "Your account has been created!"
                    self?.isSignedIn = true
                    completion("Account successfully created. You are now signed in")
                }
            }
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            DispatchQueue.main.async {
                self.isSignedIn = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error signing out: \(error.localizedDescription)"
            }
        }
    }

    // Add the resetPassword function
    func resetPassword(email: String, completion: @escaping (String?) -> Void) {
        auth.sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Error sending password reset email: \(error.localizedDescription)"
                    completion(self?.errorMessage)
                } else {
                    self?.verificationMessage = "Password reset email sent!"
                    completion(self?.verificationMessage)
                }
            }
        }
    }
}

extension SessionStore: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            let message = "Unable to fetch identity token"
            print(message)
            DispatchQueue.main.async {
                self.errorMessage = message
                self.appleSignInCompletion?(message)
                self.appleSignInCompletion = nil
            }
            return
        }
        
        let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nil)
        
        auth.signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    let message = "Error authenticating: \(error.localizedDescription)"
                    print(message)
                    self?.errorMessage = message
                    self?.appleSignInCompletion?(message)
                } else {
                    self?.isSignedIn = true
                    self?.errorMessage = nil
                    self?.appleSignInCompletion?(nil) // Success, no error message
                }
                self?.appleSignInCompletion = nil
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error
        let message = "Sign in with Apple errored: \(error.localizedDescription)"
        print(message)
        DispatchQueue.main.async {
            self.errorMessage = message
            self.appleSignInCompletion?(message)
            self.appleSignInCompletion = nil
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}
