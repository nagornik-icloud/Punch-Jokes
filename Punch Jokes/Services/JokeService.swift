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
    var setup: String // изменяемое свойство
    var punchline: String // изменяемое свойство
    var status: String // Добавляем поле для статуса шутки
    var author: String
}

class JokeService: ObservableObject {
    
    private let db = Firestore.firestore()
    private let cacheDirectory: URL
    private let jokesCacheFileName = "cached_jokes.json"
    
    @Published var allJokes = [Joke]()
    @Published var favoriteJokes = [String]()
    @Published var isLoading = false
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        // Загружаем шутки из кэша при инициализации
        if let cachedJokes = loadJokesFromCache() {
            self.allJokes = cachedJokes
        }
        
        // Затем обновляем данные с сервера
        fetchJokes { jokes in
            self.allJokes = jokes
        }
        loadFavoriteJokesFromUserDefaults()
    }
    
    // MARK: - Cache Management
    private func saveJokesToCache(_ jokes: [Joke]) {
        let encoder = JSONEncoder()
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        
        do {
            let data = try encoder.encode(jokes)
            try data.write(to: cacheURL)
            print("Jokes saved to cache: \(jokes.count) jokes")
        } catch {
            print("Failed to save jokes to cache: \(error)")
        }
    }
    
    private func loadJokesFromCache() -> [Joke]? {
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("No cached jokes found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            let jokes = try decoder.decode([Joke].self, from: data)
            print("Loaded \(jokes.count) jokes from cache")
            return jokes
        } catch {
            print("Failed to load jokes from cache: \(error)")
            return nil
        }
    }
    
    private func clearJokesCache() {
        let cacheURL = cacheDirectory.appendingPathComponent(jokesCacheFileName)
        try? FileManager.default.removeItem(at: cacheURL)
        print("Jokes cache cleared")
    }
    
    // MARK: - Joke Operations
    func fetchJokes(completion: @escaping ([Joke]) -> Void) {
        isLoading = true
        
        db.collection("jokes").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching jokes: \(error)")
                self.isLoading = false
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No jokes found")
                self.isLoading = false
                completion([])
                return
            }
            
            let jokes = documents.compactMap { document -> Joke? in
                do {
                    return try document.data(as: Joke.self)
                } catch {
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.allJokes = jokes
                self.saveJokesToCache(jokes)
                self.isLoading = false
                completion(jokes)
            }
        }
    }
    
    func addJokeForModeration(joke: Joke, completion: @escaping (Bool) -> Void) {
        // Генерируем уникальный ID для шутки
        let jokeID = UUID().uuidString
        
        // Создаём словарь с данными шутки
        let jokeData: [String: Any] = [
            "id": jokeID,
            "setup": joke.setup,
            "punchline": joke.punchline,
            "status": "pending", // Статус шутки на премодерации
            "author": joke.author
        ]
        
        // Сохраняем шутку в коллекцию с указанным ID
        db.collection("jokes")
            .document(jokeID) // Используем jokeID как имя документа
            .setData(jokeData) { error in
                if let error = error {
                    print("Ошибка при добавлении шутки: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Шутка успешно добавлена на премодерацию с ID: \(jokeID)")
                    completion(true)
                }
            }
    }
    
    // Сохранение избранных шуток в UserDefaults
    private func saveFavoriteJokesToUserDefaults() {
        UserDefaults.standard.set(favoriteJokes, forKey: "favoriteJokesKey")
    }
    
    // Загрузка избранных шуток из UserDefaults
    private func loadFavoriteJokesFromUserDefaults() {
        if let savedJokes = UserDefaults.standard.array(forKey: "favoriteJokesKey") as? [String] {
            self.favoriteJokes = savedJokes
        }
    }
    
    func toggleFavorite(_ jokeId: String) {
        if favoriteJokes.contains(jokeId) {
            favoriteJokes.removeAll { $0 == jokeId }
        } else {
            favoriteJokes.append(jokeId)
        }
        saveFavoriteJokesToUserDefaults()
    }
}
