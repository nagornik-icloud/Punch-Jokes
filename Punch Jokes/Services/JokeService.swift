//
//  JokeService.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//

import Foundation
import FirebaseFirestore
import SwiftUI

struct Joke: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var setup: String
    var punchline: String
    var status: String
    var author: String
    var createdAt: Date?
}

class JokeService: ObservableObject {
    private let db = Firestore.firestore()
    private let cacheDirectory: URL
    private let jokesCacheFileName = "cached_jokes.json"
    private let favoriteJokesKey = "FavoriteJokes"
    
    @Published var allJokes = [Joke]()
    @Published var favoriteJokes = [String]()
    @Published var isLoading = false
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        // Загружаем шутки из кеша при инициализации
        if let cachedJokes = loadJokesFromCache() {
            self.allJokes = cachedJokes
        }
        
        // Загружаем избранные шутки из кеша
        loadFavoriteJokes()
        
        // Затем обновляем данные с сервера
        Task {
            await fetchJokes()
        }
    }
    
    // MARK: - Cache Management
    private func saveJokesToCache(_ jokes: [Joke]) {
        let encoder = JSONEncoder()
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        
        do {
            let data = try encoder.encode(jokes)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save jokes to cache: \(error)")
        }
    }
    
    private func loadJokesFromCache() -> [Joke]? {
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            return try JSONDecoder().decode([Joke].self, from: data)
        } catch {
            print("Failed to load jokes from cache: \(error)")
            return nil
        }
    }
    
    private func clearJokesCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    
    // MARK: - Joke Operations
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
            
            // Обновляем данные и сохраняем в кеш
            self.allJokes = jokes
            self.saveJokesToCache(jokes)
            isLoading = false
        } catch {
            print("Error fetching jokes: \(error)")
            isLoading = false
        }
    }
    
    func addJokeForModeration(joke: Joke, completion: @escaping (Bool) -> Void) {
        let jokeID = UUID().uuidString
        
        var jokeData: [String: Any] = [
            "id": jokeID,
            "setup": joke.setup,
            "punchline": joke.punchline,
            "status": "pending",
            "author": joke.author,
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection("jokes")
            .document(jokeID)
            .setData(jokeData) { error in
                if let error = error {
                    print("Error adding joke: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
    }
    
    // MARK: - Favorite Jokes Management
    private func loadFavoriteJokes() {
        if let saved = UserDefaults.standard.array(forKey: favoriteJokesKey) as? [String] {
            self.favoriteJokes = saved
        }
    }
    
    private func saveFavoriteJokes() {
        UserDefaults.standard.set(favoriteJokes, forKey: favoriteJokesKey)
        UserDefaults.standard.synchronize()
    }
    
    func syncFavorites(with serverFavorites: [String]) {
        // Если на сервере есть избранные шутки, обновляем локальные данные
        if !serverFavorites.isEmpty {
            favoriteJokes = serverFavorites
            saveFavoriteJokes()
        } else if favoriteJokes.isEmpty {
            // Если и на сервере и локально пусто, сохраняем пустой массив
            favoriteJokes = []
            saveFavoriteJokes()
        }
        // Если на сервере пусто, а локально есть данные - оставляем локальные данные
        // и они будут отправлены на сервер при следующей синхронизации
    }
    
    func toggleFavorite(_ jokeId: String) {
        if favoriteJokes.contains(jokeId) {
            favoriteJokes.removeAll { $0 == jokeId }
        } else {
            favoriteJokes.append(jokeId)
        }
        saveFavoriteJokes()
    }
    
    func clearFavoritesCache() {
        favoriteJokes = []
        UserDefaults.standard.removeObject(forKey: favoriteJokesKey)
        UserDefaults.standard.synchronize()
    }
}
