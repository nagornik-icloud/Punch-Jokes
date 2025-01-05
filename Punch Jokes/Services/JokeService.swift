import Foundation
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

@MainActor
class JokeService: ObservableObject {
    // MARK: - Properties
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let pageSize = 20
    
    @Published var jokes: [Joke] = []
    @Published var authorImages: [String: UIImage] = [:]
    @Published var isLoading = true
    @Published var isLoadingImages = false
    @Published var error: Error?
    @Published var hasMoreJokes = true
    
    private var lastDocument: DocumentSnapshot?
    private var isLoadingMore = false
    private var loadedImagesTimestamps: [String: Date] = [:]
    
    init() {
        print("🟣 ==========================================")
        print("🟣 JokeService: Initializing...")
        loadCachedData()
        
        // Загружаем свежие данные с сервера в фоне
        Task {
            isLoading = true
            await loadInitialData()
            isLoading = false
        }
        print("🟣 JokeService: Initialization complete")
        print("🟣 ==========================================")
    }
    
    private func loadCachedData() {
        // Загружаем сохраненные шутки
        if let savedJokes = LocalStorage.loadJokes() {
            jokes = savedJokes
            print("🟣 JokeService: Loaded \(savedJokes.count) jokes from cache")
        }
        
        // Загружаем сохраненные изображения и их временные метки
        if let timestamps = UserDefaults.standard.dictionary(forKey: "AuthorImagesTimestamps") as? [String: Date] {
            loadedImagesTimestamps = timestamps
            print("🟣 JokeService: Loaded \(timestamps.count) image timestamps")
        }
        
        // Загружаем все сохраненные изображения
        let uniqueAuthors = Set(jokes.map { $0.authorId })
        for authorId in uniqueAuthors {
            if let savedImage = LocalStorage.loadImage(forUserId: authorId) {
                authorImages[authorId] = savedImage
                print("🟣 JokeService: Loaded cached image for author: \(authorId)")
            }
        }
        
        // Если в кеше нет шуток, оставляем isLoading = true
        isLoading = jokes.isEmpty
    }
    
    private func loadAllAuthorImages() async {
        print("🟣 JokeService: Starting bulk image load")
        print("🟣 JokeService: Current jokes count: \(jokes.count)")
        
        let uniqueAuthors = Set(jokes.map { $0.authorId })
        print("🟣 JokeService: Found \(uniqueAuthors.count) unique authors: \(uniqueAuthors)")
        
        for authorId in uniqueAuthors {
            print("🟣 JokeService: Processing author: \(authorId)")
            if let image = try? await loadAuthorImage(for: authorId) {
                await MainActor.run {
                    authorImages[authorId] = image
                    loadedImagesTimestamps[authorId] = Date()
                }
                LocalStorage.saveImage(image, forUserId: authorId)
                print("🟣 JokeService: Successfully saved image for author: \(authorId)")
            }
        }
        
        print("🟣 JokeService: Bulk image load complete. Loaded \(authorImages.count) images")
    }
    
    private func loadAuthorImage(for userId: String) async throws -> UIImage? {
        print("🟣 JokeService: Loading image for author: \(userId)")
        let storageRef = storage.reference().child("user_images/\(userId).jpg")
        
        do {
            let url = try await storageRef.downloadURL()
            print("🟣 JokeService: Got download URL for author: \(userId) - \(url)")
            
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🟣 JokeService: Invalid response for author: \(userId)")
                return nil
            }
            
            guard let image = UIImage(data: data) else {
                print("🟣 JokeService: Failed to create image from data for author: \(userId)")
                return nil
            }
            
            print("🟣 JokeService: Successfully loaded image for author: \(userId)")
            return image
        } catch {
            print("🟣 JokeService: Error loading image for author: \(userId) - \(error)")
            return nil
        }
    }
    
    // MARK: - Data Loading
    func loadInitialData() async {
        print("🟣 JokeService: Starting initial data load")
        do {
            let snapshot = try await db.collection("jokes")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .getDocuments()
            
            print("🟣 JokeService: Retrieved \(snapshot.documents.count) joke documents")
            
            var fetchedJokes: [Joke] = []
            for document in snapshot.documents {
                if let joke = try? await fetchJokeWithPunchlines(from: document) {
                    fetchedJokes.append(joke)
                    print("🟣 JokeService: Successfully decoded joke: \(joke.id) with \(joke.punchlines.count) punchlines")
                }
            }
            
            if jokes != fetchedJokes {
                lastDocument = snapshot.documents.last
                hasMoreJokes = !snapshot.documents.isEmpty
                jokes = fetchedJokes
                LocalStorage.saveJokes(fetchedJokes)
                print("🟣 JokeService: Updated jokes array with \(fetchedJokes.count) jokes")
                
                // Загружаем изображения сразу после обновления шуток
                print("🟣 JokeService: Starting image loading after jokes update")
                isLoadingImages = true
                await loadAllAuthorImages()
                isLoadingImages = false
                print("🟣 JokeService: Completed image loading after jokes update")
            } else {
                print("🟣 JokeService: No changes in jokes data")
            }
        } catch {
            print("🟣 JokeService: Error loading initial data: \(error)")
            self.error = error
        }
    }
    
    func loadMoreJokes() async {
        guard !isLoadingMore, hasMoreJokes, let lastDocument = lastDocument else { return }
        
        isLoadingMore = true
        print("🟣 JokeService: Loading more jokes")
        
        do {
            let snapshot = try await db.collection("jokes")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .start(afterDocument: lastDocument)
                .getDocuments()
            
            var newJokes: [Joke] = []
            for document in snapshot.documents {
                if let joke = try? await fetchJokeWithPunchlines(from: document) {
                    newJokes.append(joke)
                    print("🟣 JokeService: Successfully decoded joke: \(joke.id) with \(joke.punchlines.count) punchlines")
                }
            }
            
            self.lastDocument = snapshot.documents.last
            hasMoreJokes = !snapshot.documents.isEmpty
            
            jokes.append(contentsOf: newJokes)
            LocalStorage.saveJokes(jokes)
            
            print("🟣 JokeService: Loaded \(newJokes.count) more jokes")
        } catch {
            print("🟣 JokeService: Error loading more jokes: \(error)")
            self.error = error
        }
        
        isLoadingMore = false
    }
    
    private func fetchJokeWithPunchlines(from document: QueryDocumentSnapshot) async throws -> Joke? {
        do {
            var joke = try document.data(as: Joke.self)
            
            // Загружаем панчлайны из подколлекции текущего документа
            let punchlinesSnapshot = try await document.reference
                .collection("punchlines")
                .getDocuments()
            
            joke.punchlines = try punchlinesSnapshot.documents.compactMap { punchlineDoc in
                try punchlineDoc.data(as: Punchline.self)
            }
            
            print("🟣 JokeService: Successfully decoded joke: \(joke.id) with \(joke.punchlines.count) punchlines")
            return joke
        } catch {
            print("🟣 JokeService: Failed to decode joke from document \(document.documentID): \(error)")
            return nil
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
        jokes.insert(joke, at: 0)  // Добавляем в начало списка
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
            LocalStorage.saveJokes(jokes)
            print("🟣 JokeService: Views updated for joke \(jokeId), new count: \(jokes[index].views)")
        }
    }
    
    func toggleJokeReaction(_ jokeId: String, isLike: Bool) async throws {
        print("🟣 JokeService: Toggling \(isLike ? "like" : "dislike") for joke \(jokeId)")
        let jokeRef = db.collection("jokes").document(jokeId)
        
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
        
        LocalStorage.saveJokes(jokes)
    }
    
    func togglePunchlineReaction(_ jokeId: String, _ punchlineId: String, isLike: Bool) async throws {
        print("🟣 JokeService: Toggling \(isLike ? "like" : "dislike") for punchline \(punchlineId)")
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
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
        
        LocalStorage.saveJokes(jokes)
    }
    
    // MARK: - Punchline Operations
    func addPunchline(to jokeId: String, text: String, authorId: String) async throws {
        print("🟣 JokeService: Adding punchline to joke \(jokeId)")
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
            LocalStorage.saveJokes(jokes)
            print("🟣 JokeService: Successfully added punchline \(punchline.id) to joke \(jokeId)")
        }
    }
    
    func updatePunchlineStatus(_ jokeId: String, _ punchlineId: String, status: String) async throws {
        print("🟣 JokeService: Updating status for punchline \(punchlineId) to \(status)")
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
        try await punchlineRef.updateData([
            "status": status
        ])
        
        // Обновляем локальное состояние
        if let jokeIndex = jokes.firstIndex(where: { $0.id == jokeId }),
           let punchlineIndex = jokes[jokeIndex].punchlines.firstIndex(where: { $0.id == punchlineId }) {
            jokes[jokeIndex].punchlines[punchlineIndex].status = status
            LocalStorage.saveJokes(jokes)
            print("🟣 JokeService: Successfully updated punchline status")
        }
    }
    
    // MARK: - Helper Methods
    func getJokesByAuthor(_ authorId: String) -> [Joke] {
        let authorJokes = jokes.filter { $0.authorId == authorId }
        print("🟣 JokeService: Found \(authorJokes.count) jokes by author \(authorId)")
        return authorJokes
    }
    
    func getPunchlines(for jokeId: String, withStatus status: String? = nil) -> [Punchline] {
        guard let joke = jokes.first(where: { $0.id == jokeId }) else {
            print("🟣 JokeService: No joke found with ID \(jokeId)")
            return []
        }
        
        if let status = status {
            let filteredPunchlines = joke.punchlines.filter { $0.status == status }
            print("🟣 JokeService: Found \(filteredPunchlines.count) punchlines with status \(status) for joke \(jokeId)")
            return filteredPunchlines
        }
        
        print("🟣 JokeService: Returning all \(joke.punchlines.count) punchlines for joke \(jokeId)")
        return joke.punchlines
    }
    
    func uploadAuthorImage(_ image: UIImage, userId: String) async throws {
        print("🟣 JokeService: Uploading image for author: \(userId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        _ = try await storageRef.putDataAsync(imageData)
        
        // Обновляем кэш
        authorImages[userId] = image
        LocalStorage.saveImage(image, forUserId: userId)
        print("🟣 JokeService: Successfully uploaded and cached image for author: \(userId)")
    }
    
    func reloadAuthorImage(for userId: String) async {
        print("🟣 JokeService: Reloading image for author: \(userId)")
        
        // Проверяем, не загружается ли уже изображение
        guard authorImages[userId] == nil && !loadedImagesTimestamps.keys.contains(userId) else {
            print("🟣 JokeService: Image for author \(userId) is already loaded or loading")
            return
        }
        
        do {
            if let image = try await loadAuthorImage(for: userId) {
                authorImages[userId] = image
                loadedImagesTimestamps[userId] = Date()
                LocalStorage.saveImage(image, forUserId: userId)
                print("🟣 JokeService: Successfully reloaded and cached image for author: \(userId)")
            } else {
                print("🟣 JokeService: No image available for author: \(userId)")
            }
        } catch {
            print("🟣 JokeService: Error reloading image for author: \(userId) - \(error)")
        }
    }
}
