//
//  Joke.swift
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
    
    @Published var allJokes = [Joke]()
    
    @Published var favoriteJokes = [String]() {
        didSet {
            saveFavoriteJokesToUserDefaults()
        }
    }

    init() {
        fetchJokes { jokes in
            self.allJokes = jokes
        }
        loadFavoriteJokesFromUserDefaults()
    }
    
    private let favoriteJokesKey = "favoriteJokesKey"
    private let allJokesKey = "allJokesKey"
    
    
    // Сохранение избранных шуток в UserDefaults
    private func saveFavoriteJokesToUserDefaults() {
        UserDefaults.standard.set(favoriteJokes, forKey: favoriteJokesKey)
    }
    
    // Загрузка избранных шуток из UserDefaults
    private func loadFavoriteJokesFromUserDefaults() {
        if let savedJokes = UserDefaults.standard.array(forKey: favoriteJokesKey) as? [String] {
            self.favoriteJokes = savedJokes
        }
    }
    
    func fetchJokes(completion: @escaping ([Joke]) -> Void) {
        db.collection("jokes").getDocuments { snapshot, error in
            if let error = error {
                print("Ошибка при загрузке шуток: \(error.localizedDescription)")
                completion([])
                return
            }
            guard let snapshot = snapshot else {
                print("Нет данных в Firestore")
                completion([])
                return
            }
            let jokes = snapshot.documents.compactMap { document -> Joke? in
                do {
                    return try document.data(as: Joke.self)
                } catch {
                    return nil
                }
            }
            print("Успешно загружено шуток: \(jokes.count)")
            completion(jokes)
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
    
    
    
}

