//
//  JokeService.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import SwiftUI
import UIKit

class JokeService: ObservableObject {
    public let db = Firestore.firestore()
    let storage = Storage.storage().reference()
    let cacheDirectory: URL
    let jokesCacheFileName = "cached_jokes.json"
    let favoriteJokesKey = "FavoriteJokes"
    let usersCacheFileName = "cached_users.json"
    let userPhotosCacheFileName = "user_photos"
    
    @Published var allJokes = [Joke]()
    @Published var favoriteJokes = [String]()
    @Published var isLoading = false
    @Published var allUsers = [String]()  // массив ID пользователей
    @Published var userPhotos = [String: UIImage]()  // словарь [userID: photoURL]
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        // Загружаем данные из кэша при запуске
        if let cachedJokes = loadJokesFromCache() {
            self.allJokes = cachedJokes
        }
        if let cachedUsers = loadUsersFromCache() {
            self.allUsers = cachedUsers
        }
        loadAllUserPhotosFromCache()
        loadFavoriteJokes()
        
        // Обновляем данные с сервера
        Task {
            await fetchJokes()
            await fetchUsers()
            await fetchUserPhotos()
        }
    }
    
    // MARK: - Cache Management
    func saveJokesToCache(_ jokes: [Joke]) {
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(jokes)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save jokes to cache: \(error)")
        }
    }
    
    func loadJokesFromCache() -> [Joke]? {
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Joke].self, from: data)
        } catch {
            print("Failed to load jokes from cache: \(error)")
            return nil
        }
    }
    
    func loadFavoriteJokes() {
        if let saved = UserDefaults.standard.array(forKey: favoriteJokesKey) as? [String] {
            self.favoriteJokes = saved
        }
    }
    
    func saveFavoriteJokes() {
        UserDefaults.standard.set(favoriteJokes, forKey: favoriteJokesKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Users Cache Management
    func saveUsersToCache(_ users: [String]) {
        let cacheURL = cacheDirectory.appendingPathComponent(usersCacheFileName)
        
        do {
            let data = try JSONEncoder().encode(users)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save users to cache: \(error)")
        }
    }
    
    func loadUsersFromCache() -> [String]? {
        let cacheURL = cacheDirectory.appendingPathComponent(usersCacheFileName)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Failed to load users from cache: \(error)")
            return nil
        }
    }
    
    // MARK: - User Photos Cache Management
    func saveUserPhotoToCache(userId: String, image: UIImage) {
        let photoDirectory = cacheDirectory.appendingPathComponent(userPhotosCacheFileName)
        
        do {
            // Создаем директорию для фото если её нет
            if !FileManager.default.fileExists(atPath: photoDirectory.path) {
                try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
            }
            
            let photoPath = photoDirectory.appendingPathComponent("\(userId).jpg")
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: photoPath)
            }
        } catch {
            print("Failed to save user photo to cache: \(error)")
        }
    }
    
    func loadUserPhotoFromCache(userId: String) -> UIImage? {
        let photoPath = cacheDirectory.appendingPathComponent(userPhotosCacheFileName)
            .appendingPathComponent("\(userId).jpg")
        
        guard FileManager.default.fileExists(atPath: photoPath.path),
              let data = try? Data(contentsOf: photoPath),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    func loadAllUserPhotosFromCache() {
        for userId in allUsers {
            if let cachedImage = loadUserPhotoFromCache(userId: userId) {
                DispatchQueue.main.async {
                    self.userPhotos[userId] = cachedImage
                }
            }
        }
    }
    
    // MARK: - Server Operations
    @MainActor
    func fetchJokes() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("jokes")
                .whereField("status", isEqualTo: "approved")
                .getDocuments()
            
            let jokes = snapshot.documents.compactMap { document in
                try? document.data(as: Joke.self)
            }
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
            
            // Обновляем данные и сохраняем в кэш
            self.allJokes = jokes
            saveJokesToCache(jokes)
            isLoading = false
        } catch {
            print("Error fetching jokes: \(error)")
            isLoading = false
        }
    }
    
    @MainActor
    func fetchUsers() async {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            let users = snapshot.documents.map { $0.documentID }
            
            self.allUsers = users
            saveUsersToCache(users)
        } catch {
            print("Error fetching users: \(error)")
        }
    }
    
    @MainActor
    func fetchUserPhotos() async {
        for userId in allUsers {
            do {
                let photoRef = storage.child("user_photos/\(userId).jpg")
                let data = try await photoRef.data(maxSize: 5 * 1024 * 1024) // 5MB max
                
                if let image = UIImage(data: data) {
                    self.userPhotos[userId] = image
                    saveUserPhotoToCache(userId: userId, image: image)
                }
            } catch {
                print("Error fetching photo for user \(userId): \(error)")
                // Если не удалось загрузить с сервера, пробуем загрузить из кэша
                if let cachedImage = loadUserPhotoFromCache(userId: userId) {
                    self.userPhotos[userId] = cachedImage
                }
            }
        }
    }
    
    func addJokeForModeration(joke: Joke) async throws {
        let jokeID = UUID().uuidString
        var newJoke = joke
        newJoke.id = jokeID
        newJoke.status = "pending"
        newJoke.createdAt = Date()
        
        try await db.collection("jokes").document(jokeID).setData(from: newJoke)
        
        // Обновляем локальный список шуток
        await MainActor.run {
            allJokes.insert(newJoke, at: 0)
            saveJokesToCache(allJokes)
        }
    }
    
    func toggleFavorite(_ jokeId: String) {
        if favoriteJokes.contains(jokeId) {
            favoriteJokes.removeAll { $0 == jokeId }
        } else {
            favoriteJokes.append(jokeId)
        }
        saveFavoriteJokes()
    }
}
