import Foundation
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

@MainActor
class JokeService: ObservableObject {
    // MARK: - Properties
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var jokes: [Joke] = []
    @Published var authorImages: [String: UIImage] = [:] // userId: UIImage
    @Published var isLoading = true
    @Published var error: Error?
    
    init() {
        print("🟣 JokeService: Initializing...")
        // Загружаем сохраненные данные
        if let savedJokes = LocalStorage.loadJokes() {
            jokes = savedJokes
            print("🟣 JokeService: Loaded \(savedJokes.count) jokes from local storage")
        }
        
        // Загружаем сохраненные изображения
        for joke in jokes {
            if authorImages[joke.authorId] == nil,
               let savedImage = LocalStorage.loadImage(forUserId: joke.authorId) {
                authorImages[joke.authorId] = savedImage
                print("🟣 JokeService: Loaded image for user \(joke.authorId) from local storage")
            }
        }
        
        // Загружаем свежие данные с сервера
        Task {
            await loadInitialData()
        }
        print("🟣 JokeService: Initialization complete")
    }
    
    // MARK: - Data Loading
    func loadInitialData() async {
        print("🟣 JokeService: Starting initial data load")
        isLoading = true
        do {
            defer {
                isLoading = false
                print("🟣 JokeService: Initial data load completed")
            }
            
            // Загружаем шутки
            print("🟣 JokeService: Fetching jokes from Firestore...")
            let snapshot = try await db.collection("jokes").getDocuments()
            print("🟣 JokeService: Retrieved \(snapshot.documents.count) joke documents")
            
            var fetchedJokes: [Joke] = []
            
            for document in snapshot.documents {
                do {
                    var joke = try document.data(as: Joke.self)
                    
                    // Загружаем панчлайны для каждой шутки
                    let punchlinesSnapshot = try await document.reference.collection("punchlines").getDocuments()
                    joke.punchlines = try punchlinesSnapshot.documents.compactMap { punchlineDoc in
                        try punchlineDoc.data(as: Punchline.self)
                    }
                    
                    fetchedJokes.append(joke)
                    print("🟣 JokeService: Successfully decoded joke: \(joke.id) with \(joke.punchlines.count) punchlines")
                } catch {
                    print("🟣 JokeService: Failed to decode joke from document \(document.documentID): \(error)")
                }
            }
            
            // Проверяем, изменились ли данные
            let shouldUpdate = shouldUpdateLocalStorage(newJokes: fetchedJokes)
            if shouldUpdate {
                self.jokes = fetchedJokes
                // Сохраняем шутки локально
                LocalStorage.saveJokes(fetchedJokes)
                print("🟣 JokeService: Data changed, updated jokes array with \(fetchedJokes.count) jokes")
            } else {
                print("🟣 JokeService: No changes detected in jokes data")
            }
            
            // Загружаем изображения авторов
            let uniqueAuthors = Set(jokes.map { $0.authorId })
            print("🟣 JokeService: Found \(uniqueAuthors.count) unique authors, loading their images")
            
            for authorId in uniqueAuthors {
                if authorImages[authorId] == nil {
                    print("🟣 JokeService: Loading image for author: \(authorId)")
                    if let image = try? await loadAuthorImage(for: authorId) {
                        authorImages[authorId] = image
                        // Сохраняем изображение локально
                        LocalStorage.saveImage(image, forUserId: authorId)
                        print("🟣 JokeService: Successfully loaded image for author: \(authorId)")
                    } else {
                        print("🟣 JokeService: Failed to load image for author: \(authorId)")
                    }
                }
            }
            
        } catch {
            print("🟣 JokeService: Error during initial data load: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Joke Operations
    func addJoke(_ setup: String, authorId: String) async throws {
        let joke = Joke(
            id: UUID().uuidString,
            setup: setup,
            status: "active",
            authorId: authorId,
            createdAt: Date()
        )
        
        let jokeRef = db.collection("jokes").document(joke.id)
        try await jokeRef.setData(from: joke)
        
        // Обновляем локальное состояние
        jokes.append(joke)
        // Сохраняем обновленные данные локально
        LocalStorage.saveJokes(jokes)
    }
    
    func incrementJokeViews(_ jokeId: String) async throws {
        print("🟣 JokeService: Incrementing views for joke \(jokeId)")
        let jokeRef = db.collection("jokes").document(jokeId)
        
        try await jokeRef.updateData([
            "views": FieldValue.increment(Int64(1))
        ])
        
        // Обновляем локальное состояние
        if let index = jokes.firstIndex(where: { $0.id == jokeId }) {
            jokes[index].views += 1
            print("🟣 JokeService: Views updated for joke \(jokeId), new count: \(jokes[index].views)")
        }
    }
    
    func toggleJokeReaction(_ jokeId: String, isLike: Bool) async throws {
        print("🟣 JokeService: Toggling \(isLike ? "like" : "dislike") for joke \(jokeId)")
        let jokeRef = db.collection("jokes").document(jokeId)
        
        // Получаем текущее состояние шутки
        guard let index = jokes.firstIndex(where: { $0.id == jokeId }) else {
            print("🟣 JokeService: Joke not found in local state")
            return
        }
        
        let joke = jokes[index]
        let currentLikes = joke.likes
        let currentDislikes = joke.dislikes
        
        var updates: [String: Any] = [:]
        
        if isLike {
            if currentLikes == 1 {
                updates["likes"] = FieldValue.increment(Int64(-1))
            } else {
                updates["likes"] = FieldValue.increment(Int64(1))
                if currentDislikes == 1 {
                    updates["dislikes"] = FieldValue.increment(Int64(-1))
                }
            }
        } else {
            if currentDislikes == 1 {
                updates["dislikes"] = FieldValue.increment(Int64(-1))
            } else {
                updates["dislikes"] = FieldValue.increment(Int64(1))
                if currentLikes == 1 {
                    updates["likes"] = FieldValue.increment(Int64(-1))
                }
            }
        }
        
        // Обновляем в Firestore
        try await jokeRef.updateData(updates)
        
        // Обновляем локальное состояние
        if isLike {
            if currentLikes == 1 {
                jokes[index].likes = 0
            } else {
                jokes[index].likes = 1
                if currentDislikes == 1 {
                    jokes[index].dislikes = 0
                }
            }
        } else {
            if currentDislikes == 1 {
                jokes[index].dislikes = 0
            } else {
                jokes[index].dislikes = 1
                if currentLikes == 1 {
                    jokes[index].likes = 0
                }
            }
        }
        
        print("🟣 JokeService: Reaction updated for joke \(jokeId), likes: \(jokes[index].likes), dislikes: \(jokes[index].dislikes)")
    }
    
    // MARK: - Punchline Operations
    func addPunchline(to jokeId: String, text: String, authorId: String) async throws {
        let punchline = Punchline(
            id: UUID().uuidString,
            text: text,
            likes: 0,
            dislikes: 0,
            status: "pending",
            authorId: authorId,
            createdAt: Date()
        )
        
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchline.id)
        try await punchlineRef.setData(from: punchline)
        
        // Обновляем локальное состояние
        if let index = jokes.firstIndex(where: { $0.id == jokeId }) {
            jokes[index].punchlines.append(punchline)
            // Сохраняем обновленные данные локально
            LocalStorage.saveJokes(jokes)
        }
    }
    
    func togglePunchlineReaction(_ jokeId: String, _ punchlineId: String, isLike: Bool) async throws {
        print("🟣 JokeService: Toggling \(isLike ? "like" : "dislike") for punchline \(punchlineId) in joke \(jokeId)")
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
        // Получаем текущее состояние панчлайна
        guard let jokeIndex = jokes.firstIndex(where: { $0.id == jokeId }),
              let punchlineIndex = jokes[jokeIndex].punchlines.firstIndex(where: { $0.id == punchlineId }) else {
            print("🟣 JokeService: Punchline not found in local state")
            return
        }
        
        let punchline = jokes[jokeIndex].punchlines[punchlineIndex]
        let currentLikes = punchline.likes
        let currentDislikes = punchline.dislikes
        
        var updates: [String: Any] = [:]
        
        if isLike {
            if currentLikes == 1 {
                updates["likes"] = FieldValue.increment(Int64(-1))
            } else {
                updates["likes"] = FieldValue.increment(Int64(1))
                if currentDislikes == 1 {
                    updates["dislikes"] = FieldValue.increment(Int64(-1))
                }
            }
        } else {
            if currentDislikes == 1 {
                updates["dislikes"] = FieldValue.increment(Int64(-1))
            } else {
                updates["dislikes"] = FieldValue.increment(Int64(1))
                if currentLikes == 1 {
                    updates["likes"] = FieldValue.increment(Int64(-1))
                }
            }
        }
        
        // Обновляем в Firestore
        try await punchlineRef.updateData(updates)
        
        // Обновляем локальное состояние
        if isLike {
            if currentLikes == 1 {
                jokes[jokeIndex].punchlines[punchlineIndex].likes = 0
            } else {
                jokes[jokeIndex].punchlines[punchlineIndex].likes = 1
                if currentDislikes == 1 {
                    jokes[jokeIndex].punchlines[punchlineIndex].dislikes = 0
                }
            }
        } else {
            if currentDislikes == 1 {
                jokes[jokeIndex].punchlines[punchlineIndex].dislikes = 0
            } else {
                jokes[jokeIndex].punchlines[punchlineIndex].dislikes = 1
                if currentLikes == 1 {
                    jokes[jokeIndex].punchlines[punchlineIndex].likes = 0
                }
            }
        }
        
        print("🟣 JokeService: Reaction updated for punchline \(punchlineId), likes: \(jokes[jokeIndex].punchlines[punchlineIndex].likes), dislikes: \(jokes[jokeIndex].punchlines[punchlineIndex].dislikes)")
        
        // Сохраняем обновленные данные локально
        LocalStorage.saveJokes(jokes)
    }
    
    func updatePunchlineStatus(_ jokeId: String, _ punchlineId: String, status: String) async throws {
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
        try await punchlineRef.updateData([
            "status": status
        ])
        
        // Обновляем локальное состояние
        if let jokeIndex = jokes.firstIndex(where: { $0.id == jokeId }),
           let punchlineIndex = jokes[jokeIndex].punchlines.firstIndex(where: { $0.id == punchlineId }) {
            jokes[jokeIndex].punchlines[punchlineIndex].status = status
            // Сохраняем обновленные данные локально
            LocalStorage.saveJokes(jokes)
        }
    }
    
    // MARK: - Helper Methods
    private func shouldUpdateLocalStorage(newJokes: [Joke]) -> Bool {
        // Если количество шуток изменилось, однозначно нужно обновить
        guard newJokes.count == jokes.count else {
            print("🟣 JokeService: Jokes count changed: local \(jokes.count) vs server \(newJokes.count)")
            return true
        }
        
        // Создаем словари для быстрого поиска
        let currentJokesDict = Dictionary(uniqueKeysWithValues: jokes.map { ($0.id, $0) })
        let newJokesDict = Dictionary(uniqueKeysWithValues: newJokes.map { ($0.id, $0) })
        
        // Проверяем, есть ли различия
        for (id, newJoke) in newJokesDict {
            guard let currentJoke = currentJokesDict[id] else {
                print("🟣 JokeService: Found new joke with id: \(id)")
                return true
            }
            
            // Проверяем основные поля шутки
            if newJoke.setup != currentJoke.setup ||
               newJoke.status != currentJoke.status ||
               newJoke.views != currentJoke.views ||
               newJoke.likes != currentJoke.likes ||
               newJoke.dislikes != currentJoke.dislikes {
                print("🟣 JokeService: Joke \(id) has updated fields")
                return true
            }
            
            // Проверяем панчлайны
            if newJoke.punchlines.count != currentJoke.punchlines.count {
                print("🟣 JokeService: Punchlines count changed for joke \(id)")
                return true
            }
            
            // Создаем словари панчлайнов для быстрого поиска
            let currentPunchlinesDict = Dictionary(uniqueKeysWithValues: currentJoke.punchlines.map { ($0.id, $0) })
            let newPunchlinesDict = Dictionary(uniqueKeysWithValues: newJoke.punchlines.map { ($0.id, $0) })
            
            for (punchlineId, newPunchline) in newPunchlinesDict {
                guard let currentPunchline = currentPunchlinesDict[punchlineId] else {
                    print("🟣 JokeService: Found new punchline \(punchlineId) for joke \(id)")
                    return true
                }
                
                // Проверяем поля панчлайна
                if newPunchline.text != currentPunchline.text ||
                   newPunchline.status != currentPunchline.status ||
                   newPunchline.likes != currentPunchline.likes ||
                   newPunchline.dislikes != currentPunchline.dislikes {
                    print("🟣 JokeService: Punchline \(punchlineId) has updated fields")
                    return true
                }
            }
        }
        
        return false
    }
    
    func getJokesByAuthor(_ authorId: String) -> [Joke] {
        return jokes.filter { $0.authorId == authorId }
    }
    
    func getPunchlines(for jokeId: String, withStatus status: String? = nil) -> [Punchline] {
        guard let joke = jokes.first(where: { $0.id == jokeId }) else { return [] }
        
        if let status = status {
            return joke.punchlines.filter { $0.status == status }
        }
        return joke.punchlines
    }
    
    func uploadAuthorImage(_ image: UIImage, userId: String) async throws {
        print("🟣 JokeService: Uploading image for author: \(userId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storageRef = storage.reference().child("user_images/\(userId).jpg")
        _ = try await storageRef.putDataAsync(imageData)
        print("🟣 JokeService: Successfully uploaded image for author: \(userId)")
        
        // Обновляем кэш
        authorImages[userId] = image
        LocalStorage.saveImage(image, forUserId: userId)
    }
    
    private func loadAuthorImage(for userId: String) async throws -> UIImage? {
        let storageRef = storage.reference().child("user_images/\(userId).jpg")
        let data = try await storageRef.data(maxSize: 4 * 1024 * 1024)
        return UIImage(data: data)
    }
    
    func reloadAuthorImage(for userId: String) async {
        print("🟣 JokeService: Reloading image for author: \(userId)")
        if let image = try? await loadAuthorImage(for: userId) {
            authorImages[userId] = image
            LocalStorage.saveImage(image, forUserId: userId)
            print("🟣 JokeService: Successfully reloaded image for author: \(userId)")
        }
    }
}
