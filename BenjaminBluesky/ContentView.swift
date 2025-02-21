//
//  ContentView.swift
//  BenjaminBluesky
//
//  Created by Benjamin Chait on 2/21/25.
//

import SwiftUI

struct ContentView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var authMessage = "Enter credentials and tap Login"
    
    @AppStorage("userDID") private var did: String?
    @AppStorage("accessToken") private var accessToken: String?
    
//    @State private var accessJwt: String?
    @State private var profile: Profile?
    
    @State private var postText = ""
    @State private var postMessage = "Type a post and submit it!"

    var body: some View {
        VStack {
            if let profile = profile {
                VStack {
                    if let avatar = profile.avatar, let url = URL(string: avatar) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    }
                    
                    Text(profile.displayName ?? profile.handle)
                        .font(.title)
                        .padding()
                    
                    if let description = profile.description {
                        Text(description)
                            .padding()
                    }
                
                    TextField("Write your post here", text: $postText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                                        
                    Button("Post to Feed") {
                        guard let jwt = accessToken, let userDID = did else {
                            postMessage = "Missing authentication details!"
                            return
                        }

                        BlueskyAPI.shared.postToFeed(accessJwt: jwt, did: userDID, text: postText) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    postMessage = "Post successful!"
                                    postText = "" // Clear text field after posting
                                case .failure(let error):
                                    postMessage = "Error posting: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Text(postMessage)
                        .padding()
                    
                }
            } else {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Login") {
                    BlueskyAPI.shared.authenticate(username: username, password: password) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let auth):
                                // Store authentication details in AppStorage
                                self.accessToken = auth.accessJwt
                                self.did = auth.did // Ensure the DID is stored

                                authMessage = "Authenticated as \(auth.handle)"
                                
                                // Fetch profile after successful authentication
                                if let jwt = self.accessToken {
                                    BlueskyAPI.shared.fetchProfile(accessJwt: jwt, actor: auth.handle) { profileResult in
                                        DispatchQueue.main.async {
                                            switch profileResult {
                                            case .success(let profile):
                                                self.profile = profile
                                            case .failure(let error):
                                                authMessage = "Error fetching profile: \(error.localizedDescription)"
                                            }
                                        }
                                    }
                                }
                                
                            case .failure(let error):
                                authMessage = "Error: \(error.localizedDescription)"
                            }
                        }
                    }
                }
                .padding()
                
                Text(authMessage)
                    .padding()
            }
        }
        .padding()
    }
}
