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
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var currentUser: User?
    @Published var userImage: UIImage?
    @Published var isFirstTime = true
    
    @Published var loaded = false
    
    // MARK: - Cache
    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let userCacheFileName = "cached_user.json"
    private let imageCacheDirectory: URL
    
    private var imageCacheKey: String {
        "user_image_\(currentUser?.id ?? "default")"
    }
    
    private var storageImagePath: String {
        "user_photos/\(currentUser?.id ?? "default").jpg"
    }
    
    // MARK: - Initialization
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.imageCacheDirectory = self.cacheDirectory.appendingPathComponent("images")
        
        // Создаем директорию для изображений, если её нет
        try? FileManager.default.createDirectory(at: imageCacheDirectory, withIntermediateDirectories: true)
        
        // Теперь, когда все свойства инициализированы, можем загрузить данные из кэша
        if let cachedUser = loadUserFromCache() {
            self.currentUser = cachedUser
        }
        
        // Загружаем изображение, если есть пользователь
        if currentUser != nil {
            loadUserImage()
        }
        
        // Затем проверяем актуальные данные с сервера
        
        
        DispatchQueue.main.async {
            Task {
                await self.fetchCurrentUser()
                self.loaded = true
            }
        }
        
    }
    
    // MARK: - Image Cache
    private var imageCacheDirectoryURL: URL {
        cacheDirectory.appendingPathComponent("images")
    }
    
    // MARK: - User Cache
    private func saveUserToCache(_ user: User) {
        let encoder = JSONEncoder()
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        
        do {
            let data = try encoder.encode(user)
            try data.write(to: cacheURL)
            print("User data saved to cache")
        } catch {
            print("Failed to save user to cache: \(error)")
        }
    }
    
    private func loadUserFromCache() -> User? {
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("No cached user data found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            let user = try decoder.decode(User.self, from: data)
            print("Loaded user from cache: \(user.email)")
            return user
        } catch {
            print("Failed to load user from cache: \(error)")
            return nil
        }
    }
    
    private func clearUserCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        try? FileManager.default.removeItem(at: cacheURL)
        print("User cache cleared")
    }
    
    // MARK: - Image Handling
    private func loadUserImage() {
        print("Loading image for user: \(currentUser?.id ?? "no user")")
        print("Cache key: \(imageCacheKey)")
        
        // Try to load from memory cache first
        if let cachedImage = imageCache.object(forKey: imageCacheKey as NSString) {
            print("Found image in memory cache")
            DispatchQueue.main.async {
                self.userImage = cachedImage
            }
            return
        }
        
        // Then try to load from disk cache
        if let diskCachedImage = loadImageFromDisk() {
            print("Found image in disk cache")
            imageCache.setObject(diskCachedImage, forKey: imageCacheKey as NSString)
            DispatchQueue.main.async {
                self.userImage = diskCachedImage
            }
            return
        }
        
        print("No cached image found, loading from server")
        // If no cached image found, load from server
        loadImageFromServer()
    }
    
    private func loadImageFromDisk() -> UIImage? {
        let fileURL = imageCacheDirectoryURL.appendingPathComponent(imageCacheKey)
        print("Looking for image at: \(fileURL.path)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("No image file exists at path")
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            print("Failed to load image data from disk")
            return nil
        }
        return image
    }
    
    private func saveImageToDisk(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to compress image")
            return
        }
        
        let fileURL = imageCacheDirectoryURL.appendingPathComponent(imageCacheKey)
        print("Saving image to: \(fileURL.path)")
        
        do {
            try data.write(to: fileURL)
            print("Successfully saved image to disk")
        } catch {
            print("Failed to save image to disk: \(error.localizedDescription)")
        }
    }
    
    private func loadImageFromServer() {
        print("Loading image from server for user: \(currentUser?.id ?? "unknown")")
        let ref = storage.reference().child(storageImagePath)
        
        ref.getData(maxSize: Int64(2 * 1024 * 1024)) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading image from server: \(error.localizedDescription)")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("Successfully loaded image from server")
                self.imageCache.setObject(image, forKey: self.imageCacheKey as NSString)
                self.saveImageToDisk(image)
                
                DispatchQueue.main.async {
                    self.userImage = image
                }
            } else {
                print("No image data received from server")
            }
        }
    }
    
    func updateUserImage(_ image: UIImage) {
        print("Updating user image...")
        
        // Update memory cache and UI immediately
        imageCache.setObject(image, forKey: imageCacheKey as NSString)
        DispatchQueue.main.async {
            self.userImage = image
        }
        
        // Save to disk cache
        saveImageToDisk(image)
        
        // Upload to server
        guard let imageData = image.jpegData(compressionQuality: 0.2) else {
            print("Failed to compress image for upload")
            return
        }
        
        let ref = storage.reference().child(storageImagePath)
        print("Uploading image to path: \(storageImagePath)")
        
        ref.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                return
            }
            
            print("Image uploaded successfully")
            // После успешной загрузки обновляем кэш
            if let image = UIImage(data: imageData) {
                self?.imageCache.setObject(image, forKey: (self?.imageCacheKey as NSString? ?? ""))
                self?.saveImageToDisk(image)
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
            self?.saveUserToFirestore(newUser) { saveResult in
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
                    // Загружаем изображение после успешной авторизации
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
        guard let uid = auth.currentUser?.uid else {
            DispatchQueue.main.async {
                self.currentUser = nil
                self.clearUserCache() // Очищаем кэш если пользователь не авторизован
            }
            print("No authenticated user found.")
            return
        }
        
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            guard let data = document.data() else {
                print("No user data found.")
                return
            }
            
            let email = data["email"] as? String ?? ""
            let username = data["username"] as? String
            let name = data["name"] as? String
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let favouriteJokesIDs = data["favouriteJokesIDs"] as? [String] ?? []
            
            let user = User(id: uid,
                          email: email,
                          username: username,
                          name: name,
                          createdAt: createdAt,
                          favouriteJokesIDs: favouriteJokesIDs)
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.saveUserToCache(user)
                self.loadUserImage()
            }
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
        }
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
        let favouriteJokesIDs = data["favouriteJokesIDs"] as? [String] ?? ["нема шуток"]  // Обработка отсутствующего поля
        let createdAt = createdAtTimestamp.dateValue()
        
        print("favouriteJokesIDs: \(favouriteJokesIDs)")  // Для отладки
        
        let user = User(id: uid, email: email, username: username, name: name, createdAt: createdAt, favouriteJokesIDs: favouriteJokesIDs)
        completion(.success(user))
    }
    
    func saveUserToFirestore(_ user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "username": user.username ?? "",
            "name": user.name ?? "",
            "createdAt": Timestamp(date: user.createdAt),
            "favouriteJokesIDs": user.favouriteJokesIDs ?? []
        ]
        
        db.collection("users").document(user.id).setData(userData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
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
