//
//  UserService.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 19.12.24..
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

// MARK: - User Model
struct User: Identifiable, Codable {
    var id: String
    var email: String
    var username: String?
    var name: String?
    var createdAt: Date
    var favouriteJokesIDs: [String]?
}

// MARK: - UserService
@MainActor
class UserService: ObservableObject {
    // MARK: - Properties
    public let auth = Auth.auth()
    public let db = Firestore.firestore()
    
    @Published public var currentUser: User?
    @Published public var isFirstTime = true
    @Published public var loaded = false
    @Published public var allUsers: [User] = []
    
    // MARK: - Cache Properties
    public var userNameCache: [String: String] = [:]
    let cacheDirectory: URL
    let userCacheFileName = "cached_user.json"
    let allUsersCacheFileName = "cached_all_users.json"
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        // Загружаем данные из кэша
        loadUserFromCache()
        loadAllUsersFromCache()
        
        // Если пользователь авторизован, обновляем данные с сервера
        if auth.currentUser != nil {
            Task {
                await fetchCurrentUser()
                await fetchAllUsers()
            }
        } else {
            loaded = true
        }
    }
    
    // MARK: - Cache Management
    func loadUserFromCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        guard let data = try? Data(contentsOf: cacheURL),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        self.currentUser = user
    }
    
    func saveUserToCache() {
        guard let user = currentUser else { return }
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        if let data = try? JSONEncoder().encode(user) {
            try? data.write(to: cacheURL)
        }
    }
    
    // MARK: - All Users Cache Management
    func loadAllUsersFromCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(allUsersCacheFileName)
        guard let data = try? Data(contentsOf: cacheURL),
              let users = try? JSONDecoder().decode([User].self, from: data) else {
            return
        }
        self.allUsers = users
        
        // Обновляем кэш имен пользователей
        for user in users {
            if let username = user.username {
                userNameCache[user.id] = username
            }
        }
    }
    
    func saveAllUsersToCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(allUsersCacheFileName)
        if let data = try? JSONEncoder().encode(allUsers) {
            try? data.write(to: cacheURL)
        }
    }
    
    // MARK: - User Data Management
    func fetchCurrentUser() async {
        guard let authUser = auth.currentUser else {
            self.currentUser = nil
            self.loaded = true
            return
        }
        
        do {
            let document = try await db.collection("users").document(authUser.uid).getDocument()
            if let user = try? document.data(as: User.self) {
                self.currentUser = user
                saveUserToCache()
                self.loaded = true
            }
        } catch {
            print("Error fetching user: \(error)")
            self.loaded = true
        }
    }
    
    func fetchAllUsers() async {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            let users = snapshot.documents.compactMap { document -> User? in
                try? document.data(as: User.self)
            }
            
            await MainActor.run {
                self.allUsers = users
                
                // Обновляем кэш имен пользователей
                for user in users {
                    if let username = user.username {
                        userNameCache[user.id] = username
                    }
                }
                
                saveAllUsersToCache()
            }
        } catch {
            print("Error fetching all users: \(error)")
        }
    }
    
    // MARK: - Authentication
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
        await fetchCurrentUser()
    }
    
    func signOut() throws {
        try auth.signOut()
        self.currentUser = nil
    }
    
    func registerUser(email: String, password: String, username: String?) async throws -> User {
        let authResult = try await auth.createUser(withEmail: email, password: password)
        
        let user = User(
            id: authResult.user.uid,
            email: email,
            username: username,
            name: nil,
            createdAt: Date(),
            favouriteJokesIDs: []
        )
        
        try await saveUserToFirestore(user)
        self.currentUser = user
        saveUserToCache()
        return user
    }
    
    func saveUserToFirestore(_ user: User) async throws {
        try db.collection("users").document(user.id).setData(from: user)
    }
    
    // MARK: - User Data Updates
    func updateUsername(_ username: String) async throws {
        guard var user = currentUser else { return }
        user.username = username
        try await saveUserToFirestore(user)
        
        await MainActor.run {
            self.currentUser = user
            self.userNameCache[user.id] = username
            
            // Обновляем пользователя в общем списке
            if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
                allUsers[index] = user
                saveAllUsersToCache()
            }
            
            saveUserToCache()
        }
    }
}
