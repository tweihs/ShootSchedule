import SwiftUI
import MapKit
import AuthenticationServices
import KeychainAccess

struct WelcomeView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Approximate center of the US
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
    )

    var body: some View {
        ZStack {
            // Background Map
            Map(coordinateRegion: $region, annotationItems: sampleEvents) { event in
                MapMarker(coordinate: event.coordinates, tint: .red)
            }
            .edgesIgnoringSafeArea(.all)
            .overlay(
                Color.orange.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)// Dark overlay for opacity effect
            )

            // Foreground Content
            VStack(spacing: 24) {
                Spacer()

                // Welcome Text
                VStack(spacing: 8) {
                    Text("ShootsDB")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("ShootsDB is a fast, fun way to find clay target events.")
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
                Spacer()
                Spacer()

                // Sign In with Apple Button
                SignInWithAppleButtonView()
                    .frame(height: 50)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding()
        }
    }
}

struct SignInWithAppleButtonView: View {
    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                switch result {
                case .success(let authorization):
                    handleAuthorization(authorization: authorization)
                case .failure(let error):
                    print("Sign in with Apple failed: \(error.localizedDescription)")
                }
            }
        )
        .signInWithAppleButtonStyle(.white) // White style for visibility over dark background
    }
    
    private func handleAuthorization(authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            
            // Store user identifier securely in Keychain
            saveUserIdentifierToKeychain(userIdentifier)
            
            // Optionally handle full name and email
            if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                print("User's Name: \(givenName) \(familyName)")
            }
            if let email = email {
                print("User's Email: \(email)")
            }
        }
    }
    
    private func saveUserIdentifierToKeychain(_ identifier: String) {
        let keychain = Keychain(service: "com.yourdomain.shootsdb")
        do {
            try keychain.set(identifier, key: "appleUserIdentifier")
            print("User identifier saved to Keychain.")
        } catch {
            print("Failed to save user identifier to Keychain: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    WelcomeView()
}
