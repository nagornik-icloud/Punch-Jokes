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
import FirebaseStorage

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
class UserService: ObservableObject {
    // MARK: - Properties
    private let auth = Auth.auth()
    let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var currentUser: User?
    @Published var userImage: UIImage?
    @Published var isFirstTime = true
    @Published var loaded = false
    
    // MARK: - Cache Properties
    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let userCacheFileName = "cached_user.json"
    private let imageCacheDirectory: URL
    
    private var imageCacheKey: String {
        "user_image_\(currentUser?.id ?? "default")"
    }
    
    private var storageImagePath: String {
        "users/\(currentUser?.id ?? "default")/profile.jpg"
    }
    
    // MARK: - Initialization
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.imageCacheDirectory = self.cacheDirectory.appendingPathComponent("images")
        
        // Создаем директорию для изображений, если её нет
        try? FileManager.default.createDirectory(at: imageCacheDirectory, withIntermediateDirectories: true)
        
        // Загружаем данные из кеша
        if let cachedUser = loadUserFromCache() {
            self.currentUser = cachedUser
            loadUserImage()
        }
        
        // Обновляем данные с сервера
        Task {
            await fetchCurrentUser()
            await MainActor.run { self.loaded = true }
        }
    }
    
    // MARK: - User Cache
    func saveUserToCache(_ user: User) {
        let encoder = JSONEncoder()
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        
        do {
            let data = try encoder.encode(user)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save user to cache: \(error)")
        }
    }
    
    private func loadUserFromCache() -> User? {
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            return try JSONDecoder().decode(User.self, from: data)
        } catch {
            print("Failed to load user from cache: \(error)")
            return nil
        }
    }
    
    private func clearUserCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    
    // MARK: - Image Handling
    func loadUserImage() {
        // Try to load from memory cache first
        if let cachedImage = imageCache.object(forKey: imageCacheKey as NSString) {
            DispatchQueue.main.async {
                self.userImage = cachedImage
            }
            return
        }
        
        // Then try to load from disk cache
        if let diskCachedImage = loadImageFromDisk() {
            imageCache.setObject(diskCachedImage, forKey: imageCacheKey as NSString)
            DispatchQueue.main.async {
                self.userImage = diskCachedImage
            }
            return
        }
        
        // If no cached image found, load from server
        loadImageFromServer()
    }
    
    private func loadImageFromDisk() -> UIImage? {
        let fileURL = imageCacheDirectory.appendingPathComponent(imageCacheKey)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveImageToDisk(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = imageCacheDirectory.appendingPathComponent(imageCacheKey)
        try? data.write(to: fileURL)
    }
    
    private func loadImageFromServer() {
        let ref = storage.reference().child(storageImagePath)
        
        ref.getData(maxSize: Int64(2 * 1024 * 1024)) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading image from server: \(error)")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                self.imageCache.setObject(image, forKey: self.imageCacheKey as NSString)
                self.saveImageToDisk(image)
                
                DispatchQueue.main.async {
                    self.userImage = image
                }
            }
        }
    }
    
    func updateUserImage(_ image: UIImage) {
        // Update memory cache and UI immediately
        imageCache.setObject(image, forKey: imageCacheKey as NSString)
        userImage = image
        saveImageToDisk(image)
        
        // Upload to server
        guard let imageData = image.jpegData(compressionQuality: 0.2) else { return }
        
        let ref = storage.reference().child(storageImagePath)
        ref.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                print("Error uploading image: \(error)")
            }
        }
    }
    
    // MARK: - Authentication
    func registerUser(email: String, password: String, username: String?, completion: @escaping (Result<User, Error>) -> Void) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User creation failed."])))
                return
            }
            
            let newUser = User(id: user.uid,
                             email: email,
                             username: username,
                             createdAt: Date(),
                             favouriteJokesIDs: [])
            
            self?.currentUser = newUser
            self?.saveUserToCache(newUser)
            self?.saveUserToFirestoreWithCompletion(newUser) { saveResult in
                completion(saveResult.map { newUser })
            }
        }
    }
    
    func loginUser(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let uid = result?.user.uid else {
                completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID."])))
                return
            }
            
            self?.loadUser(uid: uid) { result in
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.saveUserToCache(user)
                    DispatchQueue.main.async {
                        self?.loadUserImage()
                    }
                    completion(.success(user))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchCurrentUser() async {
        guard let userId = auth.currentUser?.uid else {
            await MainActor.run {
                self.currentUser = nil
                self.clearUserCache()
            }
            return
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            let user = try document.data(as: User.self)
            
            await MainActor.run {
                self.currentUser = user
                if let jokeService = getJokeService() {
                    jokeService.syncFavorites(with: user.favouriteJokesIDs ?? [])
                }
                self.saveUserToCache(user)
                self.loadUserImage()
            }
        } catch {
            print("Error fetching user: \(error)")
        }
    }
    
    private func getJokeService() -> JokeService? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene?.windows.first
        let rootViewController = window?.rootViewController
        
        if let hostingController = rootViewController as? UIHostingController<AnyView> {
            let mirror = Mirror(reflecting: hostingController.rootView)
            for child in mirror.children {
                if let jokeService = child.value as? JokeService {
                    return jokeService
                }
            }
        }
        return nil
    }
    
    private func loadUser(uid: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User data not found."])))
                return
            }
            
            self.parseUser(from: data, uid: uid, completion: completion)
        }
    }
    
    private func parseUser(from data: [String: Any], uid: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let email = data["email"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data."])))
            return
        }
        
        let username = data["username"] as? String
        let name = data["name"] as? String
        let favouriteJokesIDs = data["favouriteJokesIDs"] as? [String] ?? []
        let createdAt = createdAtTimestamp.dateValue()
        
        let user = User(id: uid, email: email, username: username, name: name, createdAt: createdAt, favouriteJokesIDs: favouriteJokesIDs)
        completion(.success(user))
    }
    
    func saveUserToFirestore(_ user: User) async throws {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "username": user.username ?? "",
            "name": user.name ?? "",
            "createdAt": Timestamp(date: user.createdAt),
            "favouriteJokesIDs": user.favouriteJokesIDs ?? []
        ]
        
        try await db.collection("users").document(user.id).setData(userData)
    }
    
    private func saveUserToFirestoreWithCompletion(_ user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await saveUserToFirestore(user)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func logoutUser(completion: @escaping (Bool) -> Void) {
        do {
            try auth.signOut()
            self.currentUser = nil
            self.userImage = nil
            clearUserCache() // Очищаем кэш при выходе
            completion(true)
        } catch {
            completion(false)
        }
    }
}
