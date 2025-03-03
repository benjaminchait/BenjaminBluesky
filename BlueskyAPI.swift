//
//  BlueskyAPI.swift
//  BenjaminBluesky
//
//  Created by Benjamin Chait on 2/21/25.
//

import Foundation
import KeychainSwift

struct AuthResponse: Codable {
    let accessJwt: String
    let did: String
    let handle: String
}

struct Profile: Codable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case did
        case handle
        case displayName = "displayName"  // Adjust if necessary
        case avatar = "avatar"            // Adjust if necessary
        case description = "description"  // Adjust if necessary
    }
}

class BlueskyAPI {
    static let shared = BlueskyAPI()
    
    let baseURL = URL(string: "https://bsky.social/xrpc/")!
    let keychain = KeychainSwift()

    struct SessionResponse: Codable {
        let did: String
        let accessJwt: String
        let handle: String
    }

    func authenticate(username: String, password: String, completion: @escaping (Result<SessionResponse, Error>) -> Void) {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.server.createSession")!

        let body: [String: Any] = [
            "identifier": username,
            "password": password
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let session = try JSONDecoder().decode(SessionResponse.self, from: data)
                
                // Old code: UserDefaults
                // UserDefaults.standard.set(session.did, forKey: "userDID")
                // UserDefaults.standard.set(session.accessJwt, forKey: "accessToken")
                // UserDefaults.standard.set(session.handle, forKey: "identifier")
                // UserDefaults.standard.synchronize()
                
                // New code: Store in Keychain
                self.keychain.set(session.accessJwt, forKey: "accessToken")
                self.keychain.set(session.did, forKey: "userDID")
                self.keychain.set(session.handle, forKey: "identifier")

                completion(.success(session))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
    
    func fetchProfile(accessJwt: String, actor: String, completion: @escaping (Result<Profile, Error>) -> Void) {
        let accessToken = keychain.get("accessToken") ?? accessJwt
        let userDID = keychain.get("userDID") ?? actor // Use actor as fallback
        
        var components = URLComponents(string: "https://bsky.social/xrpc/app.bsky.actor.getProfile")!
        components.queryItems = [URLQueryItem(name: "actor", value: actor)] // Add the actor parameter
        
        guard let url = components.url else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessJwt)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(jsonString)")
            }

            do {
                let profile = try JSONDecoder().decode(Profile.self, from: data)
                completion(.success(profile))
            } catch {
                print("Decoding Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }

    func postToFeed(accessJwt: String, did: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let accessToken = keychain.get("accessToken") ?? accessJwt
        let userDID = keychain.get("userDID") ?? did
        
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.repo.createRecord")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessJwt)", forHTTPHeaderField: "Authorization")
        
        // Generate the current timestamp in ISO 8601 format
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.string(from: Date())

        let body: [String: Any] = [
            "repo": userDID,  // Use the authenticated user's DID
            "collection": "app.bsky.feed.post",
            "record": [
                "$type": "app.bsky.feed.post",
                "text": text,
                "createdAt": createdAt
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let response = response as? HTTPURLResponse {
                print("HTTP Response: \(response.statusCode)")
            }

            if let data = data {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response: \(jsonString)")
                }
            }
            
            completion(.success(()))
        }
        
        task.resume()
    }
}
