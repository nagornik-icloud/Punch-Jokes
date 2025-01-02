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

class UserService: ObservableObject {
    // MARK: - Properties
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    @Published var currentUser: User?
    @Published var allUsers: [User] = []
    @Published var userNameCache: [String: String] = [:]
    @Published var isLoading = true
    @Published var error: Error?
    
    init() {
        print("👤 UserService: Initializing...")
        
        // Загружаем кэш имен пользователей
        userNameCache = LocalStorage.loadUserNameCache()
        isLoading = false
        print("👤 UserService: Loaded username cache with \(userNameCache.count) entries")
        
        Task {
            await loadInitialData()
            setupAuthStateListener()
        }
        print("👤 UserService: Initialization complete")
    }
    
    private func setupAuthStateListener() {
        print("👤 UserService: Setting up auth state listener")
        auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else {
                print("👤 UserService: Self is nil in auth listener")
                return
            }
            
            if let user = user {
                print("👤 UserService: Auth state changed - user logged in with ID: \(user.uid)")
                Task {
                    await self.fetchCurrentUser(userId: user.uid)
                }
            } else {
                print("👤 UserService: Auth state changed - user logged out")
                DispatchQueue.main.async {
                    self.currentUser = nil
                }
            }
        }
    }
    
    private func loadInitialData() async {
        print("👤 UserService: Starting initial data load")
        do {
            isLoading = true
            defer { 
                isLoading = false
                print("👤 UserService: Initial data load completed")
            }
            
            // Загружаем всех пользователей
            print("👤 UserService: Fetching all users")
            let snapshot = try await db.collection("users").getDocuments()
            print("👤 UserService: Retrieved \(snapshot.documents.count) user documents")
            
            let fetchedUsers = try snapshot.documents.compactMap { document -> User? in
                do {
                    let user = try document.data(as: User.self)
                    print("👤 UserService: Successfully decoded user: \(user.id)")
                    return user
                } catch {
                    print("👤 UserService: Failed to decode user from document \(document.documentID): \(error)")
                    return nil
                }
            }
            
            // Обновляем список пользователей
            await MainActor.run {
                self.allUsers = fetchedUsers
                print("👤 UserService: Updated users array with \(fetchedUsers.count) users")
                
                // Обновляем кэш имен пользователей
                for user in fetchedUsers {
                    let name = user.username ?? user.name ?? "Пользователь"
                    self.userNameCache[user.id] = name
                    print("👤 UserService: Cached name for user \(user.id): \(name)")
                }
                
                // Сохраняем кэш
                LocalStorage.saveUserNameCache(self.userNameCache)
            }
            
            // Если есть текущий пользователь, загружаем его данные
            if let currentUserId = auth.currentUser?.uid {
                print("👤 UserService: Current user found, fetching details for ID: \(currentUserId)")
                await fetchCurrentUser(userId: currentUserId)
            } else {
                print("👤 UserService: No current user found")
            }
            
        } catch {
            print("👤 UserService: Error during initial data load: \(error)")
            self.error = error
        }
    }
    
    private func fetchCurrentUser(userId: String) async {
        print("👤 UserService: Fetching current user with ID: \(userId)")
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            await MainActor.run {
                if let user = try? document.data(as: User.self) {
                    self.currentUser = user
                    print("👤 UserService: Successfully fetched and set current user: \(user.id)")
                } else {
                    print("👤 UserService: Failed to decode current user document")
                    self.error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode user data"])
                }
            }
        } catch {
            print("👤 UserService: Error fetching current user: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func logOut() throws {
        print("👤 UserService: Attempting to log out")
        do {
            try auth.signOut()
            currentUser = nil
            print("👤 UserService: Successfully logged out")
        } catch {
            print("👤 UserService: Error during logout: \(error)")
            throw error
        }
    }
    
    func updateUser(_ user: User) async throws {
        print("👤 UserService: Updating user with ID: \(user.id)")
        do {
            try await db.collection("users").document(user.id).setData(from: user)
            print("👤 UserService: Successfully updated user in Firestore")
            
            await MainActor.run {
                if user.id == currentUser?.id {
                    currentUser = user
                    print("👤 UserService: Updated current user")
                }
                if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
                    allUsers[index] = user
                    print("👤 UserService: Updated user in allUsers array")
                }
                userNameCache[user.id] = user.username ?? user.name ?? "Пользователь"
                print("👤 UserService: Updated user in name cache")
                
                // Сохраняем обновленный кэш
                LocalStorage.saveUserNameCache(userNameCache)
            }
        } catch {
            print("👤 UserService: Error updating user: \(error)")
            throw error
        }
    }
    
    func saveUserToFirestore() async throws {
        print("👤 UserService: Attempting to save current user to Firestore")
        guard let user = currentUser else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user available"])
            print("👤 UserService: Error - No current user available")
            throw error
        }
        try await updateUser(user)
        print("👤 UserService: Successfully saved current user to Firestore")
    }
}
