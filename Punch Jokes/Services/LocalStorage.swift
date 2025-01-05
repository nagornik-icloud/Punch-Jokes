import Foundation
import UIKit

// MARK: - Cache Models
struct CacheMetadata: Codable {
    let lastUpdate: Date
    let version: Int
    let count: Int
    
    static let currentVersion = 1
    
    static func create(count: Int) -> CacheMetadata {
        CacheMetadata(
            lastUpdate: Date(),
            version: currentVersion,
            count: count
        )
    }
}

enum LocalStorage {
    static let userDefaults = UserDefaults.standard
    static let cacheValidityDuration: TimeInterval = 5 * 60 // 5 минут
    
    // MARK: - Paths
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static var jokesDirectory: URL {
        documentsDirectory.appendingPathComponent("jokes", isDirectory: true)
    }
    
    static var usersDirectory: URL {
        documentsDirectory.appendingPathComponent("users", isDirectory: true)
    }
    
    static var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("images", isDirectory: true)
    }
    
    static var metadataDirectory: URL {
        documentsDirectory.appendingPathComponent("metadata", isDirectory: true)
    }
    
    // MARK: - Directory Setup
    static func setupDirectories() {
        let directories = [jokesDirectory, usersDirectory, imagesDirectory, metadataDirectory]
        
        for directory in directories {
            if !FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Cache Validation
    static func isCacheValid(type: String) -> Bool {
        guard let metadata = loadMetadata(for: type) else { return false }
        let age = Date().timeIntervalSince(metadata.lastUpdate)
        return age <= cacheValidityDuration && metadata.version == CacheMetadata.currentVersion
    }
    
    private static func saveMetadata(_ metadata: CacheMetadata, for type: String) {
        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: metadataDirectory.appendingPathComponent("\(type).json"))
            print(" LocalStorage: Saved metadata for \(type)")
        } catch {
            print(" LocalStorage: Failed to save metadata for \(type): \(error)")
        }
    }
    
    private static func loadMetadata(for type: String) -> CacheMetadata? {
        do {
            let data = try Data(contentsOf: metadataDirectory.appendingPathComponent("\(type).json"))
            return try JSONDecoder().decode(CacheMetadata.self, from: data)
        } catch {
            print(" LocalStorage: Failed to load metadata for \(type): \(error)")
            return nil
        }
    }
    
    // MARK: - Jokes Storage
    static func saveJokes(_ jokes: [Joke]) {
        do {
            let data = try JSONEncoder().encode(jokes)
            try data.write(to: jokesDirectory.appendingPathComponent("jokes.json"))
            saveMetadata(CacheMetadata.create(count: jokes.count), for: "jokes")
            print(" LocalStorage: Saved \(jokes.count) jokes")
        } catch {
            print(" LocalStorage: Failed to save jokes: \(error)")
        }
    }
    
    static func loadJokes() -> [Joke]? {
        guard isCacheValid(type: "jokes") else {
            print(" LocalStorage: Jokes cache is invalid or expired")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: jokesDirectory.appendingPathComponent("jokes.json"))
            let jokes = try JSONDecoder().decode([Joke].self, from: data)
            print(" LocalStorage: Loaded \(jokes.count) jokes")
            return jokes
        } catch {
            print(" LocalStorage: Failed to load jokes: \(error)")
            return nil
        }
    }
    
    // MARK: - Users Storage
    static func saveUsers(_ users: [User]) {
        do {
            let data = try JSONEncoder().encode(users)
            try data.write(to: usersDirectory.appendingPathComponent("users.json"))
            saveMetadata(CacheMetadata.create(count: users.count), for: "users")
            print(" LocalStorage: Saved \(users.count) users")
        } catch {
            print(" LocalStorage: Failed to save users: \(error)")
        }
    }
    
    static func loadUsers() -> [User]? {
        guard isCacheValid(type: "users") else {
            print(" LocalStorage: Users cache is invalid or expired")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: usersDirectory.appendingPathComponent("users.json"))
            let users = try JSONDecoder().decode([User].self, from: data)
            print(" LocalStorage: Loaded \(users.count) users")
            return users
        } catch {
            print(" LocalStorage: Failed to load users: \(error)")
            return nil
        }
    }
    
    static func saveCurrentUser(_ user: User) {
        do {
            let data = try JSONEncoder().encode(user)
            try data.write(to: usersDirectory.appendingPathComponent("current_user.json"))
            saveMetadata(CacheMetadata.create(count: 1), for: "current_user")
            print(" LocalStorage: Saved current user")
        } catch {
            print(" LocalStorage: Failed to save current user: \(error)")
        }
    }
    
    static func loadCurrentUser() -> User? {
        guard isCacheValid(type: "current_user") else {
            print(" LocalStorage: Current user cache is invalid or expired")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: usersDirectory.appendingPathComponent("current_user.json"))
            let user = try JSONDecoder().decode(User.self, from: data)
            print(" LocalStorage: Loaded current user")
            return user
        } catch {
            print(" LocalStorage: Failed to load current user: \(error)")
            return nil
        }
    }
    
    // MARK: - Images Storage
    static func saveImage(_ image: UIImage, forUserId userId: String) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let fileURL = imagesDirectory.appendingPathComponent("\(userId).jpg")
        
        do {
            try data.write(to: fileURL)
            saveMetadata(CacheMetadata.create(count: 1), for: "image_\(userId)")
            print(" LocalStorage: Saved image for user \(userId)")
        } catch {
            print(" LocalStorage: Failed to save image for user \(userId): \(error)")
        }
    }
    
    static func loadImage(forUserId userId: String) -> UIImage? {
        guard isCacheValid(type: "image_\(userId)") else {
            print(" LocalStorage: Image cache for user \(userId) is invalid or expired")
            return nil
        }
        
        let fileURL = imagesDirectory.appendingPathComponent("\(userId).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - User Cache Storage
    static func saveUserNameCache(_ cache: [String: String]) {
        userDefaults.set(cache, forKey: "userNameCache")
        saveMetadata(CacheMetadata.create(count: cache.count), for: "username_cache")
        print(" LocalStorage: Saved username cache with \(cache.count) entries")
    }
    
    static func loadUserNameCache() -> [String: String] {
        guard isCacheValid(type: "username_cache") else {
            print(" LocalStorage: Username cache is invalid or expired")
            return [:]
        }
        
        let cache = userDefaults.dictionary(forKey: "userNameCache") as? [String: String] ?? [:]
        print(" LocalStorage: Loaded username cache with \(cache.count) entries")
        return cache
    }
    
    // MARK: - Cache Cleanup
    static func cleanupOldCache() {
        let directories = [jokesDirectory, usersDirectory, imagesDirectory, metadataDirectory]
        let fileManager = FileManager.default
        
        for directory in directories {
            guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for url in contents {
                // Проверяем метаданные файла
                if let metadata = loadMetadata(for: url.deletingPathExtension().lastPathComponent),
                   Date().timeIntervalSince(metadata.lastUpdate) > cacheValidityDuration {
                    try? fileManager.removeItem(at: url)
                    print(" LocalStorage: Removed old cache file: \(url.lastPathComponent)")
                }
            }
        }
    }
    
    // MARK: - Clear All Cache
    static func clearAllCache() {
        print("🗑️ LocalStorage: Clearing all cache...")
        
        // Очищаем UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Очищаем файлы
        let fileManager = FileManager.default
        let cachePaths = [
            NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first,
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        ]
        
        for cachePath in cachePaths.compactMap({ $0 }) {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: cachePath)
                for file in files {
                    let filePath = (cachePath as NSString).appendingPathComponent(file)
                    try fileManager.removeItem(atPath: filePath)
                    print("🗑️ LocalStorage: Removed file at \(filePath)")
                }
            } catch {
                print("🗑️ LocalStorage: Error clearing cache at \(cachePath): \(error)")
            }
        }
        
        print("🗑️ LocalStorage: Cache cleared")
    }
}
