import Foundation
import UIKit

enum LocalStorage {
    static let userDefaults = UserDefaults.standard
    
    // MARK: - Paths
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static var jokesDirectory: URL {
        documentsDirectory.appendingPathComponent("jokes", isDirectory: true)
    }
    
    static var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("images", isDirectory: true)
    }
    
    // MARK: - Directory Setup
    static func setupDirectories() {
        let directories = [jokesDirectory, imagesDirectory]
        
        for directory in directories {
            if !FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Jokes Storage
    static func saveJokes(_ jokes: [Joke]) {
        do {
            let data = try JSONEncoder().encode(jokes)
            try data.write(to: jokesDirectory.appendingPathComponent("jokes.json"))
            print("💾 LocalStorage: Saved \(jokes.count) jokes")
        } catch {
            print("💾 LocalStorage: Failed to save jokes: \(error)")
        }
    }
    
    static func loadJokes() -> [Joke]? {
        do {
            let data = try Data(contentsOf: jokesDirectory.appendingPathComponent("jokes.json"))
            let jokes = try JSONDecoder().decode([Joke].self, from: data)
            print("💾 LocalStorage: Loaded \(jokes.count) jokes")
            return jokes
        } catch {
            print("💾 LocalStorage: Failed to load jokes: \(error)")
            return nil
        }
    }
    
    // MARK: - Images Storage
    static func saveImage(_ image: UIImage, forUserId userId: String) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let fileURL = imagesDirectory.appendingPathComponent("\(userId).jpg")
        
        do {
            try data.write(to: fileURL)
            print("💾 LocalStorage: Saved image for user \(userId)")
        } catch {
            print("💾 LocalStorage: Failed to save image for user \(userId): \(error)")
        }
    }
    
    static func loadImage(forUserId userId: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent("\(userId).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - User Cache Storage
    static func saveUserNameCache(_ cache: [String: String]) {
        userDefaults.set(cache, forKey: "userNameCache")
        print("💾 LocalStorage: Saved username cache with \(cache.count) entries")
    }
    
    static func loadUserNameCache() -> [String: String] {
        let cache = userDefaults.dictionary(forKey: "userNameCache") as? [String: String] ?? [:]
        print("💾 LocalStorage: Loaded username cache with \(cache.count) entries")
        return cache
    }
}
