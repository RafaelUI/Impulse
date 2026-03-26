import Foundation
import AuthenticationServices
import AppKit

// MARK: - Модель пользователя

struct SignedInUser {
    let userID: String
    let fullName: String
    let email: String?
}

// MARK: - Менеджер Sign in with Apple

@MainActor
final class AppleSignInManager: NSObject, ObservableObject {

    static let shared = AppleSignInManager()

    @Published var signedInUser: SignedInUser? = nil
    @Published var isSignedIn: Bool = false

    private let userIDKey = "appleSignIn.userID"
    private let fullNameKey = "appleSignIn.fullName"
    private let emailKey = "appleSignIn.email"

    override init() {
        super.init()
        restoreSession()
    }

    // MARK: - Восстановление сессии при запуске

    private func restoreSession() {
        guard let savedID = UserDefaults.standard.string(forKey: userIDKey) else { return }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: savedID) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    let name = UserDefaults.standard.string(forKey: self?.fullNameKey ?? "") ?? ""
                    let email = UserDefaults.standard.string(forKey: self?.emailKey ?? "")
                    self?.signedInUser = SignedInUser(userID: savedID, fullName: name, email: email)
                    self?.isSignedIn = true
                case .revoked, .notFound:
                    self?.clearSession()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Запуск авторизации

    func signIn(presentingWindow: NSWindow) {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = PresentationContextProvider(window: presentingWindow)
        controller.performRequests()
    }

    // MARK: - Выход

    func signOut() {
        clearSession()
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: fullNameKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        signedInUser = nil
        isSignedIn = false
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userID = credential.user
        let fullName: String = {
            let components = credential.fullName
            let given = components?.givenName ?? ""
            let family = components?.familyName ?? ""
            let name = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            return name.isEmpty ? "Пользователь" : name
        }()
        let email = credential.email

        // Сохраняем в UserDefaults (имя/email Apple даёт только при первом входе)
        UserDefaults.standard.set(userID, forKey: userIDKey)
        if !fullName.isEmpty && fullName != "Пользователь" {
            UserDefaults.standard.set(fullName, forKey: fullNameKey)
        }
        if let email {
            UserDefaults.standard.set(email, forKey: emailKey)
        }

        let savedName = UserDefaults.standard.string(forKey: fullNameKey) ?? fullName
        let savedEmail = UserDefaults.standard.string(forKey: emailKey)

        Task { @MainActor in
            self.signedInUser = SignedInUser(userID: userID, fullName: savedName, email: savedEmail)
            self.isSignedIn = true
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // Пользователь отменил или произошла ошибка — ничего не делаем
        print("Sign in with Apple error: \(error.localizedDescription)")
    }
}

// MARK: - Presentation context для macOS

private final class PresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    private let window: NSWindow

    init(window: NSWindow) {
        self.window = window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window
    }
}
