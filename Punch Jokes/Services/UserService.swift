import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class UserService: ObservableObject {
    // MARK: - Properties
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    let reactionsService = UserReactionsService()
    let localFavoritesService = LocalFavoritesService()
    
    @Published var currentUser: User?
    @Published var allUsers: [User] = []
    @Published var userNameCache: [String: String] = [:]
    @Published var isLoading = true
    @Published var error: Error?
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    init() {
        defer {isLoading = false}
        print("👤 UserService: Initializing...")
        if auth.currentUser != nil {
            print("👤 UserService: No user logged in")
            loadCachedData()
        }
        
        setupAuthStateListener()
        
        // Загружаем свежие данные с сервера в фоне
        Task {
            await loadInitialData()
        }
        print("👤 UserService: Initialization complete")
    }
    
    private func loadCachedData() {
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
                    await self.reactionsService.syncWithFirestore(userId: user.uid)
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
            
            if fetchedUsers != allUsers {
                allUsers = fetchedUsers
                LocalStorage.saveUsers(fetchedUsers)
                print("👤 UserService: Updated users array with \(fetchedUsers.count) users")
                
                updateUserNameCache(with: fetchedUsers)
            } else {
                print("👤 UserService: No changes in users data")
            }
            
            if let currentUserId = auth.currentUser?.uid {
                print("👤 UserService: Current user found, fetching details for ID: \(currentUserId)")
                await fetchCurrentUser(userId: currentUserId)
            }
            
        } catch {
            handleError(error, message: "Error during initial data load")
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
                handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode user data"]), message: "Failed to decode current user document")
            }
        } catch {
            handleError(error, message: "Error fetching current user")
        }
    }
    
    func logOut() throws {
        print("👤 UserService: Attempting to log out")
        do {
            try auth.signOut()
            currentUser = nil
            LocalStorage.saveCurrentUser(User(id: "", email: ""))  // Сбрасываем кеш
            reactionsService.clearReactions()
            print("👤 UserService: Successfully logged out")
        } catch {
            handleError(error, message: "Error during logout")
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
            
            updateUserNameCache(with: [user])
            
        } catch {
            handleError(error, message: "Error updating user")
            throw error
        }
    }
    
    func saveUserToFirestore() async throws {
        print("👤 UserService: Attempting to save current user to Firestore")
        guard let user = currentUser else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user available"])
            handleError(error, message: "Error - No current user available")
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
            handleError(error, message: "Login failed")
            throw error
        }
    }
    
    func register(email: String, password: String, username: String, name: String? = nil) async throws {
        print("👤 UserService: Attempting to register with email: \(email)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = User(id: result.user.uid, email: email, username: username, name:name)
            
            try await db.collection("users").document(user.id).setData(from: user)
            currentUser = user
            LocalStorage.saveCurrentUser(user)
            
            if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
                allUsers[index] = user
            } else {
                allUsers.append(user)
            }
            LocalStorage.saveUsers(allUsers)
            
            updateUserNameCache(with: [user])
            
            print("👤 UserService: Successfully registered and saved user data")
        } catch {
            handleError(error, message: "Registration failed")
            throw error
        }
    }
    
    private func syncFavorites() async throws {
        guard let currentUser = currentUser else { return }
        
//        let localFavoritesService = await LocalFavoritesService()
        let localFavorites = await localFavoritesService.favorites
        
        let serverFavorites = Set(currentUser.favouriteJokesIDs ?? [])
        
        let mergedFavorites = localFavorites.union(serverFavorites)
        
        var updatedUser = currentUser
        updatedUser.favouriteJokesIDs = Array(mergedFavorites)
        
        try await updateUser(updatedUser)
        
        await localFavoritesService.clearFavorites()
        print("👤 UserService: Successfully synced favorites")
    }
    
    func resetPassword(email: String) async throws {
        print("👤 UserService: Attempting to send password reset for email: \(email)")
        do {
            try await auth.sendPasswordReset(withEmail: email)
            print("👤 UserService: Password reset email sent")
        } catch {
            handleError(error, message: "Password reset failed")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    private func updateUserNameCache(with users: [User]) {
        var newCache = userNameCache
        for user in users {
            let name = user.username ?? user.name ?? "Пользователь"
            newCache[user.id] = name
        }
        
        if newCache != userNameCache {
            userNameCache = newCache
            LocalStorage.saveUserNameCache(newCache)
            print("👤 UserService: Updated username cache")
        }
    }
    
    private func handleError(_ error: Error, message: String) {
        print("👤 UserService: \(message) - \(error)")
        self.error = error
        alertMessage = message
        showAlert = true
    }
}
