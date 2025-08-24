//
//  KeychainHelper.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import Security
import AuthenticationServices

struct KeychainHelper {
    static func save(key: String, value: String) -> Bool {
        let data = value.data(using: .utf8)!
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary

        SecItemDelete(query) // Remove existing item if present
        let status = SecItemAdd(query, nil)
        return status == errSecSuccess
    }

    static func load(key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

struct SignInWithAppleHandler {
    private static let userKey = "AppleUserIdentifier"

    static func signIn(completion: @escaping (Result<String, Error>) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = SignInDelegate(completion: completion)
        controller.performRequests()
    }

    static func loadExistingUser() -> String? {
        return KeychainHelper.load(key: userKey)
    }

    private class SignInDelegate: NSObject, ASAuthorizationControllerDelegate {
        let completion: (Result<String, Error>) -> Void

        init(completion: @escaping (Result<String, Error>) -> Void) {
            self.completion = completion
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user

                // Save to Keychain
                let saved = KeychainHelper.save(key: SignInWithAppleHandler.userKey, value: userIdentifier)
                if saved {
                    completion(.success(userIdentifier))
                } else {
                    completion(.failure(NSError(domain: "KeychainError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save user identifier"])))
                }
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            completion(.failure(error))
        }
    }
}


