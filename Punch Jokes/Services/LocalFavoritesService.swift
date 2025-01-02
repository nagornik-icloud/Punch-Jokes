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
        print("📱 Getting favorite jokes from UserDefaults")
        if let favorites = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            print("📱 Found favorites: \(favorites)")
            return Set(favorites)
        }
        print("📱 No favorites found")
        return Set()
    }
    
    func addFavoriteJoke(_ jokeId: String) {
        print("📱 Adding joke to favorites: \(jokeId)")
        favorites.insert(jokeId)
        saveFavorites()
        print("📱 Updated favorites: \(favorites)")
    }
    
    func removeFavoriteJoke(_ jokeId: String) {
        print("📱 Removing joke from favorites: \(jokeId)")
        favorites.remove(jokeId)
        saveFavorites()
        print("📱 Updated favorites: \(favorites)")
    }
    
    func clearFavorites() {
        print("📱 Clearing all favorites")
        favorites.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.favoritesKey)
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favorites), forKey: Self.favoritesKey)
    }
    
    func contains(_ jokeId: String) -> Bool {
        return favorites.contains(jokeId)
    }
}
