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
    static let cacheValidityDuration: TimeInterval = 5 * 60 // 5 minutes
    
    // MARK: - Paths
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static var jokesDirectory: URL {
        documentsDirectory.appendingPathComponent("jokes", isDirectory: true)
    }
    
    static var punchlinesDirectory: URL {
        documentsDirectory.appendingPathComponent("punchlines", isDirectory: true)
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
        let directories = [jokesDirectory, usersDirectory, imagesDirectory, metadataDirectory, punchlinesDirectory]
        
        for directory in directories {
            if !FileManager.default.fileExists(atPath: directory.path) {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("LocalStorage: Failed to create directory \(directory.path): \(error)")
                }
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
            print("LocalStorage: Saved metadata for \(type)")
        } catch {
            print("LocalStorage: Failed to save metadata for \(type): \(error)")
        }
    }
    
    private static func loadMetadata(for type: String) -> CacheMetadata? {
        do {
            let data = try Data(contentsOf: metadataDirectory.appendingPathComponent("\(type).json"))
            return try JSONDecoder().decode(CacheMetadata.self, from: data)
        } catch {
            print("LocalStorage: Failed to load metadata for \(type): \(error)")
            return nil
        }
    }
    
    // MARK: - Generic Storage
    private static func saveData<T: Codable>(_ data: T, to directory: URL, fileName: String, metadataType: String) {
        DispatchQueue.global(qos: .background).async {
            do {
                let encodedData = try JSONEncoder().encode(data)
                try encodedData.write(to: directory.appendingPathComponent(fileName))
                saveMetadata(CacheMetadata.create(count: (data as? [Any])?.count ?? 1), for: metadataType)
                print("LocalStorage: Saved data to \(fileName)")
            } catch {
                print("LocalStorage: Failed to save data to \(fileName): \(error)")
            }
        }
    }
    
    private static func loadData<T: Codable>(from directory: URL, fileName: String, metadataType: String) -> T? {
        guard isCacheValid(type: metadataType) else {
            print("LocalStorage: Cache for \(metadataType) is invalid or expired")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent(fileName))
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            print("LocalStorage: Loaded data from \(fileName)")
            return decodedData
        } catch {
            print("LocalStorage: Failed to load data from \(fileName): \(error)")
            return nil
        }
    }
    
    // MARK: - Jokes Storage
    static func saveJokes(_ jokes: [Joke]) {
        saveData(jokes, to: jokesDirectory, fileName: "jokes.json", metadataType: "jokes")
    }
    
    static func loadJokes() -> [Joke]? {
        return loadData(from: jokesDirectory, fileName: "jokes.json", metadataType: "jokes")
    }
    
    // MARK: - Punchlines Storage
    static func savePunchlines(_ punchlines: [Punchline], forJoke jokeId: String) {
        saveData(punchlines, to: punchlinesDirectory, fileName: "\(jokeId).json", metadataType: "punchlines_\(jokeId)")
    }
    
    static func loadPunchlines(forJoke jokeId: String) -> [Punchline]? {
        return loadData(from: punchlinesDirectory, fileName: "\(jokeId).json", metadataType: "punchlines_\(jokeId)")
    }
    
    // MARK: - Users Storage
    static func saveUsers(_ users: [User]) {
        saveData(users, to: usersDirectory, fileName: "users.json", metadataType: "users")
    }
    
    static func loadUsers() -> [User]? {
        return loadData(from: usersDirectory, fileName: "users.json", metadataType: "users")
    }
    
    static func saveCurrentUser(_ user: User) {
        saveData(user, to: usersDirectory, fileName: "current_user.json", metadataType: "current_user")
    }
    
    static func loadCurrentUser() -> User? {
        return loadData(from: usersDirectory, fileName: "current_user.json", metadataType: "current_user")
    }
    
    // MARK: - Images Storage
    static func saveImage(_ image: UIImage, forUserId userId: String) {
        DispatchQueue.global(qos: .background).async {
            do {
                let imageFile = imagesDirectory.appendingPathComponent("\(userId).jpg")
                if let data = image.jpegData(compressionQuality: 0.7) {
                    try data.write(to: imageFile)
                    saveMetadata(CacheMetadata.create(count: 1), for: "image_\(userId)")
                    print("LocalStorage: Saved image for user \(userId)")
                }
            } catch {
                print("LocalStorage: Failed to save image for user \(userId): \(error)")
            }
        }
    }
    
    static func loadImage(forUserId userId: String) -> UIImage? {
        guard isCacheValid(type: "image_\(userId)") else {
            print("LocalStorage: Image cache for user \(userId) is invalid or expired")
            return nil
        }
        
        do {
            let imageFile = imagesDirectory.appendingPathComponent("\(userId).jpg")
            let data = try Data(contentsOf: imageFile)
            if let image = UIImage(data: data) {
                print("LocalStorage: Loaded image for user \(userId)")
                return image
            }
            return nil
        } catch {
            print("LocalStorage: Failed to load image for user \(userId): \(error)")
            return nil
        }
    }
    
    // MARK: - User Cache Storage
    static func saveUserNameCache(_ cache: [String: String]) {
        userDefaults.set(cache, forKey: "userNameCache")
        saveMetadata(CacheMetadata.create(count: cache.count), for: "username_cache")
        print("LocalStorage: Saved username cache with \(cache.count) entries")
    }
    
    static func loadUserNameCache() -> [String: String] {
        guard isCacheValid(type: "username_cache") else {
            print("LocalStorage: Username cache is invalid or expired")
            return [:]
        }
        
        let cache = userDefaults.dictionary(forKey: "userNameCache") as? [String: String] ?? [:]
        print("LocalStorage: Loaded username cache with \(cache.count) entries")
        return cache
    }
    
    // MARK: - Cache Cleanup
    static func cleanupOldCache() {
        let directories = [jokesDirectory, usersDirectory, imagesDirectory, metadataDirectory, punchlinesDirectory]
        let fileManager = FileManager.default
        
        for directory in directories {
            guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for url in contents {
                if let metadata = loadMetadata(for: url.deletingPathExtension().lastPathComponent),
                   Date().timeIntervalSince(metadata.lastUpdate) > cacheValidityDuration {
                    try? fileManager.removeItem(at: url)
                    print("LocalStorage: Removed old cache file: \(url.lastPathComponent)")
                }
            }
        }
    }
    
    // MARK: - Clear All Cache
    static func clearAllCache() {
        print("🗑️ LocalStorage: Clearing all cache...")
        
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
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