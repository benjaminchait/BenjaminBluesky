//
//  BlueskyAPI.swift
//  BenjaminBluesky
//
//  Created by Benjamin Chait on 2/21/25.
//

import Foundation

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

    func authenticate(username: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("com.atproto.server.createSession")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["identifier": username, "password": password]
        
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
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                completion(.success(authResponse))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func fetchProfile(accessJwt: String, actor: String, completion: @escaping (Result<Profile, Error>) -> Void) {
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


}
