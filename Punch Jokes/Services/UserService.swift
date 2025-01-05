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

@MainActor
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
        loadCachedData()
        setupAuthStateListener()
        
        // Загружаем свежие данные с сервера в фоне
        Task {
            await loadInitialData()
        }
        print("👤 UserService: Initialization complete")
    }
    
    private func loadCachedData() {
        // Загружаем кэшированные данные
        if let cachedUsers = LocalStorage.loadUsers() {
            allUsers = cachedUsers
            print("👤 UserService: Loaded \(cachedUsers.count) users from cache")
        }
        
        if let cachedCurrentUser = LocalStorage.loadCurrentUser() {
            currentUser = cachedCurrentUser
            print("👤 UserService: Loaded current user from cache")
        }
        
        userNameCache = LocalStorage.loadUserNameCache()
        print("👤 UserService: Loaded username cache with \(userNameCache.count) entries")
        
        isLoading = false
    }
    
    private func setupAuthStateListener() {
        print("👤 UserService: Setting up auth state listener")
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let user = user {
                    print("👤 UserService: Auth state changed - user logged in with ID: \(user.uid)")
                    await self.fetchCurrentUser(userId: user.uid)
                } else {
                    print("👤 UserService: Auth state changed - user logged out")
                    self.currentUser = nil
                    LocalStorage.saveCurrentUser(User(id: "", email: ""))  // Сбрасываем кеш текущего пользователя
                }
            }
        }
    }
    
    func loadInitialData() async {
        print("👤 UserService: Starting initial data load")
        do {
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
            
            // Проверяем, изменились ли данные
            if fetchedUsers != allUsers {
                allUsers = fetchedUsers
                LocalStorage.saveUsers(fetchedUsers)
                print("👤 UserService: Updated users array with \(fetchedUsers.count) users")
                
                // Обновляем кэш имен пользователей
                var newCache: [String: String] = [:]
                for user in fetchedUsers {
                    let name = user.username ?? user.name ?? "Пользователь"
                    newCache[user.id] = name
                }
                
                if newCache != userNameCache {
                    userNameCache = newCache
                    LocalStorage.saveUserNameCache(newCache)
                    print("👤 UserService: Updated username cache")
                }
            } else {
                print("👤 UserService: No changes in users data")
            }
            
            // Если есть текущий пользователь, обновляем его данные
            if let currentUserId = auth.currentUser?.uid {
                print("👤 UserService: Current user found, fetching details for ID: \(currentUserId)")
                await fetchCurrentUser(userId: currentUserId)
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
            if let user = try? document.data(as: User.self) {
                if user != currentUser {
                    currentUser = user
                    LocalStorage.saveCurrentUser(user)
                    print("👤 UserService: Successfully fetched and saved current user: \(user.id)")
                } else {
                    print("👤 UserService: Current user data hasn't changed")
                }
            } else {
                print("👤 UserService: Failed to decode current user document")
                error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode user data"])
            }
        } catch {
            print("👤 UserService: Error fetching current user: \(error)")
            self.error = error
        }
    }
    
    func logOut() throws {
        print("👤 UserService: Attempting to log out")
        do {
            try auth.signOut()
            currentUser = nil
            LocalStorage.saveCurrentUser(User(id: "", email: ""))  // Сбрасываем кеш
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
            
            if user.id == currentUser?.id {
                currentUser = user
                LocalStorage.saveCurrentUser(user)
                print("👤 UserService: Updated current user")
            }
            
            if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
                allUsers[index] = user
                LocalStorage.saveUsers(allUsers)
                print("👤 UserService: Updated user in allUsers array")
            }
            
            let name = user.username ?? user.name ?? "Пользователь"
            userNameCache[user.id] = name
            LocalStorage.saveUserNameCache(userNameCache)
            print("👤 UserService: Updated user in name cache")
            
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
    
    // MARK: - Authentication Methods
    func login(email: String, password: String) async throws {
        print("👤 UserService: Attempting to login with email: \(email)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await fetchCurrentUser(userId: result.user.uid)
            try await syncFavorites()
            print("👤 UserService: Successfully logged in and fetched user data")
        } catch {
            print("👤 UserService: Login failed with error: \(error)")
            throw error
        }
    }
    
    func register(email: String, password: String, username: String) async throws {
        print("👤 UserService: Attempting to register with email: \(email)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = User(id: result.user.uid, email: email, username: username)
            
            try await db.collection("users").document(user.id).setData(from: user)
            currentUser = user
            LocalStorage.saveCurrentUser(user)
            
            if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
                allUsers[index] = user
            } else {
                allUsers.append(user)
            }
            LocalStorage.saveUsers(allUsers)
            
            userNameCache[user.id] = username
            LocalStorage.saveUserNameCache(userNameCache)
            
            print("👤 UserService: Successfully registered and saved user data")
        } catch {
            print("👤 UserService: Registration failed with error: \(error)")
            throw error
        }
    }
    
    private func syncFavorites() async throws {
        guard let currentUser = currentUser else { return }
        
        // Получаем локальные избранные
        let localFavoritesService = await LocalFavoritesService()
        let localFavorites = await localFavoritesService.favorites
        
        // Получаем серверные избранные
        let serverFavorites = Set(currentUser.favouriteJokesIDs ?? [])
        
        // Объединяем локальные и серверные избранные
        let mergedFavorites = localFavorites.union(serverFavorites)
        
        // Обновляем пользователя
        var updatedUser = currentUser
        updatedUser.favouriteJokesIDs = Array(mergedFavorites)
        
        // Сохраняем на сервер и в кэш
        try await updateUser(updatedUser)
        
        // Очищаем локальные избранные после успешной синхронизации
        await localFavoritesService.clearFavorites()
        print("👤 UserService: Successfully synced favorites")
    }
    
    func resetPassword(email: String) async throws {
        print("👤 UserService: Attempting to send password reset for email: \(email)")
        do {
            try await auth.sendPasswordReset(withEmail: email)
            print("👤 UserService: Password reset email sent")
        } catch {
            print("👤 UserService: Password reset failed: \(error)")
            throw error
        }
    }
}
