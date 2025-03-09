import Foundation
import SwiftUI

@MainActor
class LocalFavoritesService: ObservableObject {
    @Published private(set) var favorites: Set<String> = []
    private static let favoritesKey = "local_favorite_jokes"
    
    init() {
        favorites = Self.loadFavorites()
    }
    
    private static func loadFavorites() -> Set<String> {
        print("📱 [\(Date())] Getting favorite jokes from UserDefaults")
        if let favorites = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            print("📱 [\(Date())] Found favorites: \(favorites)")
            return Set(favorites)
        }
        print("📱 [\(Date())] No favorites found")
        return Set()
    }
    
    func addFavoriteJoke(_ jokeId: String) {
        print("📱 [\(Date())] Adding joke to favorites: \(jokeId)")
        favorites.insert(jokeId)
        saveFavorites()
        print("📱 [\(Date())] Updated favorites: \(favorites)")
        notifyUser("Added to favorites")
    }
    
    func removeFavoriteJoke(_ jokeId: String) {
        print("📱 [\(Date())] Removing joke from favorites: \(jokeId)")
        favorites.remove(jokeId)
        saveFavorites()
        print("📱 [\(Date())] Updated favorites: \(favorites)")
        notifyUser("Removed from favorites")
    }
    
    func clearFavorites() {
        print("📱 [\(Date())] Clearing all favorites")
        favorites.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.favoritesKey)
        notifyUser("Cleared all favorites")
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favorites), forKey: Self.favoritesKey)
    }
    
    func contains(_ jokeId: String) -> Bool {
        return favorites.contains(jokeId)
    }
    
    private func notifyUser(_ message: String) {
        // Implement user notification logic here, e.g., using a SwiftUI alert or toast
        print("📱 [\(Date())] Notification: \(message)")
    }
}