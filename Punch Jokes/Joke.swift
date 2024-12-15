//
//  Joke.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//


import Foundation
import FirebaseFirestore
//import Firebase


struct Joke: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var setup: String // изменяемое свойство
    var punchline: String // изменяемое свойство
    var status: String // Добавляем поле для статуса шутки
}


class JokeService {
    private let db = Firestore.firestore()

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
                        print("Ошибка декодирования документа \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                }

                print("Успешно загружено шуток: \(jokes.count)")
                completion(jokes)
            }
        
    }


    
    // Добавление новой шутки на сервер для премодерации
    func addJokeForModeration(joke: Joke, completion: @escaping (Bool) -> Void) {
        // Генерируем уникальный ID для шутки
        let jokeID = UUID().uuidString

        // Создаём словарь с данными шутки
        let jokeData: [String: Any] = [
            "id": jokeID,
            "setup": joke.setup,
            "punchline": joke.punchline,
            "status": "pending" // Статус шутки на премодерации
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

