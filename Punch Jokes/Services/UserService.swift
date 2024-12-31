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
@MainActor
class UserService: ObservableObject {
    // MARK: - Properties
    public let auth = Auth.auth()
    public let db = Firestore.firestore()
    public let storage = Storage.storage()
    
    @Published public var currentUser: User?
    @Published public var userImage: UIImage?
    @Published public var isFirstTime = true
    @Published public var loaded = false
    
    // MARK: - Cache Properties
    public let imageCache = NSCache<NSString, UIImage>()
    public var userNameCache: [String: String] = [:]
    public let imageCacheDirectory: URL
    public var imageCacheTimestamps: [String: Date] = [:]
    let cacheDirectory: URL
    let userCacheFileName = "cached_user.json"
    public let otherUsersCacheDirectory: URL
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.imageCacheDirectory = cacheDirectory.appendingPathComponent("user_images")
        self.otherUsersCacheDirectory = cacheDirectory.appendingPathComponent("other_users")
        
        // Создаем директории для кэша
        try? FileManager.default.createDirectory(at: imageCacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: otherUsersCacheDirectory, withIntermediateDirectories: true)
        
        // Загружаем данные из кэша
        loadUserFromCache()
        loadUserImage()
        
        // Если пользователь авторизован, обновляем данные с сервера
        if auth.currentUser != nil {
            Task {
                await fetchCurrentUser()
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
    
    func loadCacheTimestamps() {
        let timestampsURL = cacheDirectory.appendingPathComponent("image_timestamps.json")
        if let data = try? Data(contentsOf: timestampsURL),
           let timestamps = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            imageCacheTimestamps = timestamps.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }
    
    func saveCacheTimestamps() {
        let timestampsURL = cacheDirectory.appendingPathComponent("image_timestamps.json")
        let timestamps = imageCacheTimestamps.mapValues { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(timestamps) {
            try? data.write(to: timestampsURL)
        }
    }
    
    func clearImageCache(for userId: String) {
        imageCache.removeObject(forKey: "user_photo_\(userId)" as NSString)
        imageCacheTimestamps.removeValue(forKey: userId)
        saveCacheTimestamps()
    }
    
    // MARK: - Other Users Cache
    func loadUserFromCache(userId: String) -> User? {
        let cacheURL = otherUsersCacheDirectory.appendingPathComponent("\(userId).json")
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    func saveUserToCache(_ user: User) {
        let cacheURL = otherUsersCacheDirectory.appendingPathComponent("\(user.id).json")
        if let data = try? JSONEncoder().encode(user) {
            try? data.write(to: cacheURL)
        }
    }
    
    // MARK: - User Data Management
    @MainActor
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
                
                // Загружаем изображение пользователя
                await loadUserImageFromServer()
            }
        } catch {
            print("Error fetching user: \(error)")
            self.loaded = true
        }
    }
    
    // MARK: - Image Handling
    func loadUserImage() {
        guard let userId = currentUser?.id else { return }
        
        // Проверяем кэш в памяти
        if let cachedImage = imageCache.object(forKey: "user_photo_\(userId)" as NSString) {
            self.userImage = cachedImage
            return
        }
        
        // Проверяем кэш на диске
        let imageURL = imageCacheDirectory.appendingPathComponent("\(userId).jpg")
        if let data = try? Data(contentsOf: imageURL),
           let image = UIImage(data: data) {
            self.userImage = image
            imageCache.setObject(image, forKey: "user_photo_\(userId)" as NSString)
            return
        }
        
        // Если в кэше нет, загружаем с сервера
        Task {
            await loadUserImageFromServer()
        }
    }
    
    func loadUserImageFromServer() async {
        guard let userId = currentUser?.id else { return }
        
        let imageRef = storage.reference().child("user_photos/\(userId).jpg")
        
        do {
            let data = try await imageRef.data(maxSize: 5 * 1024 * 1024)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.userImage = image
                }
                
                // Сохраняем в кэш
                imageCache.setObject(image, forKey: "user_photo_\(userId)" as NSString)
                imageCacheTimestamps[userId] = Date()
                saveCacheTimestamps()
                
                // Сохраняем на диск
                let imageURL = imageCacheDirectory.appendingPathComponent("\(userId).jpg")
                try? data.write(to: imageURL)
            }
        } catch {
            print("Error loading user image: \(error)")
        }
    }
    
    func uploadUserImage(_ imageData: Data) async throws {
        guard let userId = currentUser?.id else { return }
        
        // Очищаем кэш
        clearImageCache(for: userId)
        
        // Сохраняем локально
        if let image = UIImage(data: imageData) {
            await MainActor.run {
                self.userImage = image
            }
            imageCache.setObject(image, forKey: "user_photo_\(userId)" as NSString)
            let imageURL = imageCacheDirectory.appendingPathComponent("\(userId).jpg")
            try? imageData.write(to: imageURL)
        }
        
        // Отправляем на сервер
        let storageRef = storage.reference()
        let imageRef = storageRef.child("user_photos/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await imageRef.putData(imageData, metadata: metadata)
        
        // Обновляем временную метку
        imageCacheTimestamps[userId] = Date()
        saveCacheTimestamps()
    }
    
    @MainActor
    func updateUserImage(_ image: UIImage) async throws {
        guard let userId = currentUser?.id else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID"]) }
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to data"]) }
        
        // Сохраняем в кэш
        self.userImage = image
        imageCache.setObject(image, forKey: "user_photo_\(userId)" as NSString)
        
        let imageURL = imageCacheDirectory.appendingPathComponent("\(userId).jpg")
        try? imageData.write(to: imageURL)
        
        // Загружаем на сервер
        let storageRef = storage.reference()
        let imageRef = storageRef.child("user_photos/\(userId).jpg")
        
        _ = try await imageRef.putDataAsync(imageData)
    }
    
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
    
    func getJokeService() -> JokeService? {
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
    
    func loadUser(uid: String, completion: @escaping (Result<User, Error>) -> Void) {
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
    
    func parseUser(from data: [String: Any], uid: String, completion: @escaping (Result<User, Error>) -> Void) {
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
    
    func saveUserToFirestoreWithCompletion(_ user: User, completion: @escaping (Result<Void, Error>) -> Void) {
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
    
    func clearUserCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(userCacheFileName)
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
