//
//  MeteorClient+SignInWithApple.swift
//
//  Created by Tom Brückner on 2024-03-03.
//

import AuthenticationServices
import Foundation

/// SignInWithApple
/// https://medium.com/@jeremysh/signinwithapplebutton-swiftui-authentication-2d9d3146cb2d

public extension MeteorClient {
    func signInWithApple(_ authResults: ASAuthorization, client: String? = nil, callback: MeteorMethodCallback? = nil) {
        guard let credentials = authResults.credential as? ASAuthorizationAppleIDCredential,
              let authCode = credentials.authorizationCode,
              let authToken = String(data: authCode, encoding: .utf8),
              let idTokenJWT = credentials.identityToken,
              let idToken = String(data: idTokenJWT, encoding: .utf8) else { return }
        let appleId = credentials.user
        /// email and name received ONLY in the first login
        let email = credentials.email
        let fullName = credentials.fullName
        let firstName = fullName?.givenName
        let lastName = fullName?.familyName
        /// setup payload
        var serviceData: [String: Any] = [:]
        var options: [String: Any] = [:]
        var profile: [String: Any] = [:]
        var scopes: [String] = []
        options["profile"] = profile
        serviceData["id"] = appleId
        serviceData["accessToken"] = authToken
        serviceData["idToken"] = idToken
        if fullName != nil {
            var name: [String: Any] = [:]
            name["firstName"] = firstName
            name["lastName"] = lastName
            serviceData["name"] = name
            profile["name"] = name
            scopes.append("name")
        }
        if email != nil {
            serviceData["email"] = email
            profile["email"] = email
            scopes.append("email")
        }
        serviceData["scope"] = scopes.joined(separator: " ")
        var parameters: [String: Any] = [:]
        parameters["serviceData"] = serviceData
        parameters["options"] = options

        if client != nil {
            parameters["client"] = client
        }

        //        let body = ["appleIdentityToken": idToken]
        //        guard let jsonData = try? JSONEncoder().encode(body) else { return }
        call("users:nativeSignInWithApple", params: [parameters]) { result, error in
            if var result = result as? MeteorKeyValue {
                /// Meteor client expexts userId as id
                result["id"] = result["userId"]
                if fullName != nil {
                    result["firstName"] = firstName
                    result["lastName"] = lastName
                }
                self.queues.userMain.addOperation {
                    self.onLoginResult(result, error: error)
                    callback?(result, error)
                }
                return
            }
            self.queues.userMain.addOperation {
                self.onLoginResult(nil, error: error)
                callback?(nil, error)
            }
        }
    }
}
