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

class JokeService: ObservableObject {
    public let db = Firestore.firestore()
    let cacheDirectory: URL
    let jokesCacheFileName = "cached_jokes.json"
    let favoriteJokesKey = "FavoriteJokes"
    
    @Published var allJokes = [Joke]()
    @Published var favoriteJokes = [String]()
    @Published var isLoading = false
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        // Загружаем данные из кэша при запуске
        if let cachedJokes = loadJokesFromCache() {
            self.allJokes = cachedJokes
        }
        loadFavoriteJokes()
        
        // Обновляем данные с сервера
        Task {
            await fetchJokes()
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
