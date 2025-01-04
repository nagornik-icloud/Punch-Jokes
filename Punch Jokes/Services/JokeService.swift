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
            isLoading = false
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
            isLoading = true
            await loadInitialData()
        }
        print("🟣 JokeService: Initialization complete")
    }
    
    func loadInitialData() async {
        print("🟣 JokeService: Starting initial data load")
        do {
            defer {
                isLoading = false
                print("🟣 JokeService: Initial data load completed")
            }
            
            // Загружаем шутки
            print("🟣 JokeService: Fetching jokes from Firestore...")
            let snapshot = try await db.collection("jokes").getDocuments()
            print("🟣 JokeService: Retrieved \(snapshot.documents.count) joke documents")
            
            let fetchedJokes = try snapshot.documents.compactMap { document -> Joke? in
                do {
                    let joke = try document.data(as: Joke.self)
                    print("🟣 JokeService: Successfully decoded joke: \(joke.id)")
                    return joke
                } catch {
                    print("🟣 JokeService: Failed to decode joke from document \(document.documentID): \(error)")
                    return nil
                }
            }
            
            self.jokes = fetchedJokes
            // Сохраняем шутки локально
            LocalStorage.saveJokes(fetchedJokes)
            print("🟣 JokeService: Updated jokes array with \(fetchedJokes.count) jokes")
            
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
    
    private func loadAuthorImage(for authorId: String) async throws -> UIImage? {
        // Сначала пробуем загрузить из локального хранилища
        if let savedImage = LocalStorage.loadImage(forUserId: authorId) {
            print("🟣 JokeService: Loaded image for \(authorId) from local storage")
            return savedImage
        }
        
        print("🟣 JokeService: Attempting to load image for \(authorId) from server")
        let storageRef = storage.reference().child("user_images/\(authorId).jpg")
        let data = try await storageRef.data(maxSize: 4 * 1024 * 1024)
        if let image = UIImage(data: data) {
            // Сохраняем изображение локально
            LocalStorage.saveImage(image, forUserId: authorId)
            print("🟣 JokeService: Successfully loaded image for \(authorId)")
            return image
        }
        print("🟣 JokeService: Failed to create UIImage from data for \(authorId)")
        return nil
    }
    
    func addJoke(_ setup: String, _ punchline: String, author: String) async throws {
        let joke = Joke(
            id: UUID().uuidString,
            setup: setup,
            punchline: punchline,
            status: "pending",
            authorId: author,
            createdAt: Date()
        )
        try await addJoke(joke)
    }
    
    func addJoke(_ joke: Joke) async throws {
        print("🟣 JokeService: Adding new joke with ID: \(joke.id)")
        isLoading = true
        defer {
            isLoading = false
            print("🟣 JokeService: Finished adding joke")
        }
        
        try await db.collection("jokes").document(joke.id).setData(from: joke)
        await loadInitialData()
    }
    
    func deleteJoke(_ jokeId: String) async throws {
        print("🟣 JokeService: Deleting joke with ID: \(jokeId)")
        isLoading = true
        defer {
            isLoading = false
            print("🟣 JokeService: Finished deleting joke")
        }
        
        try await db.collection("jokes").document(jokeId).delete()
        await loadInitialData()
    }
    
    func updateJoke(_ joke: Joke) async throws {
        print("🟣 JokeService: Updating joke with ID: \(joke.id)")
        isLoading = true
        defer {
            isLoading = false
            print("🟣 JokeService: Finished updating joke")
        }
        
        try await db.collection("jokes").document(joke.id).setData(from: joke)
        await loadInitialData()
    }
    
    func uploadAuthorImage(_ image: UIImage, userId: String) async throws {
        let storageRef = storage.reference().child("user_images/\(userId).jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        await MainActor.run {
            self.authorImages[userId] = image
            // Сохраняем в локальное хранилище
            LocalStorage.saveImage(image, forUserId: userId)
        }
    }
    
    func reloadAuthorImage(for userId: String) async throws {
        print("🟣 JokeService: Reloading image for author: \(userId)")
        let image = try await loadAuthorImage(for: userId)
        await MainActor.run {
            self.authorImages[userId] = image
            if let image = image {
                LocalStorage.saveImage(image, forUserId: userId)
            }
        }
        print("🟣 JokeService: Successfully reloaded image for author: \(userId)")
    }
    
    // MARK: - Helper Methods
    func getJokesByAuthor(_ authorId: String) -> [Joke] {
        return jokes.filter { $0.authorId == authorId }
    }
    
    func getLatestJokes(limit: Int = 10) -> [Joke] {
        return Array(jokes.sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }.prefix(limit))
    }
}
