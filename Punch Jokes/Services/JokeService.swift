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
    
    @Published private(set) var jokes: [Joke] = []
    @Published var authorImages: [String: UIImage] = [:]
    @Published var error: Error?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isLoadingImages = false
    @Published private(set) var hasMoreJokes = true
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    // Store user reactions
    private var userReactions: [String: String] = [:] // [punchlineId: "like"/"dislike"]
    
    private var lastDocument: QueryDocumentSnapshot?
    private var preloadedJokes: [Joke] = []
    private var isPreloading = false
    private var loadedImagesTimestamps: [String: Date] = [:]
    
    // Начинаем предзагрузку когда осталось 5 шуток до конца
    private let preloadThreshold = 5
    
    init() {
        print("🟣 ==========================================")
        print("🟣 JokeService: Initializing...")
        Task {
            isLoading = true
            await loadData()
            isLoading = false
        }
        print("🟣 JokeService: Initialization complete")
        print("🟣 ==========================================")
    }
    
    func loadData() async {
        print("🟣 JokeService: Starting data load")
        loadCachedData()
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
                
                // Начинаем предзагрузку следующей страницы
                Task {
                    await preloadNextPage()
                }
                
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
    
    private func loadCachedData() {
        // Загружаем сохраненные шутки
        if let savedJokes = LocalStorage.loadJokes() {
            jokes = savedJokes
            print("🟣 JokeService: Loaded \(savedJokes.count) jokes from cache")
        }
        
        // Загружаем сохраненные изображения
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
            
            // Проверяем, нужно ли обновлять изображение
            let lastUpdate = loadedImagesTimestamps[authorId] ?? .distantPast
            let shouldUpdate = Date().timeIntervalSince(lastUpdate) > 3600 // Обновляем раз в час
            
            if !shouldUpdate, let cachedImage = authorImages[authorId] {
                print("🟣 JokeService: Using cached image for author: \(authorId)")
                continue
            }
            
            if let image = try? await loadAuthorImage(for: authorId) {
                await MainActor.run {
                    authorImages[authorId] = image
                    loadedImagesTimestamps[authorId] = Date()
                }
                LocalStorage.saveImage(image, forUserId: authorId)
                print("🟣 JokeService: Successfully saved image for author: \(authorId)")
                
                // Сохраняем временные метки
                UserDefaults.standard.set(loadedImagesTimestamps, forKey: "AuthorImagesTimestamps")
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
            
            // Оптимизируем изображение перед сохранением
            let optimizedImage = optimizeImage(image)
            print("🟣 JokeService: Successfully loaded and optimized image for author: \(userId)")
            return optimizedImage
        } catch {
            print("🟣 JokeService: Error loading image for author: \(userId) - \(error)")
            return nil
        }
    }
    
    private func optimizeImage(_ image: UIImage, maxSize: CGFloat = 200) -> UIImage {
        // Если изображение меньше максимального размера, возвращаем как есть
        let originalSize = max(image.size.width, image.size.height)
        if originalSize <= maxSize {
            return image
        }
        
        // Вычисляем новый размер, сохраняя пропорции
        let ratio = maxSize / originalSize
        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )
        
        // Создаем новый контекст для отрисовки
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // Отрисовываем изображение в новом размере
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        // Получаем оптимизированное изображение
        guard let optimizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        
        print("🟣 JokeService: Optimized image from \(Int(originalSize))px to \(Int(maxSize))px")
        return optimizedImage
    }
    
    // MARK: - Data Loading
    private func preloadNextPage() async {
        guard !isPreloading, hasMoreJokes, let lastDocument = lastDocument else { return }
        
        isPreloading = true
        print("🟣 JokeService: Preloading next page")
        
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
                    print("🟣 JokeService: Successfully preloaded joke: \(joke.id)")
                }
            }
            
            preloadedJokes = newJokes
            print("🟣 JokeService: Preloaded \(newJokes.count) jokes")
        } catch {
            print("🟣 JokeService: Error preloading jokes: \(error)")
        }
        
        isPreloading = false
    }
    
    func loadMoreJokes() async {
        guard !isLoadingMore, hasMoreJokes else { return }
        
        isLoadingMore = true
        print("🟣 JokeService: Loading more jokes")
        
        // Если есть предзагруженные шутки, используем их
        if !preloadedJokes.isEmpty {
            print("🟣 JokeService: Using preloaded jokes")
            jokes.append(contentsOf: preloadedJokes)
            
            // Обновляем lastDocument для следующей загрузки
            if let lastJoke = preloadedJokes.last,
               let snapshot = try? await db.collection("jokes")
                .whereField("id", isEqualTo: lastJoke.id)
                .getDocuments(),
               let lastDoc = snapshot.documents.first {
                lastDocument = lastDoc
            }
            
            // Очищаем предзагруженные шутки и начинаем загрузку следующей страницы
            preloadedJokes = []
            Task {
                await preloadNextPage()
            }
            
            isLoadingMore = false
            return
        }
        
        // Если предзагруженных шуток нет, загружаем обычным способом
        do {
            let snapshot = try await db.collection("jokes")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .start(afterDocument: lastDocument!)
                .getDocuments()
            
            var newJokes: [Joke] = []
            for document in snapshot.documents {
                if let joke = try? await fetchJokeWithPunchlines(from: document) {
                    newJokes.append(joke)
                    print("🟣 JokeService: Successfully decoded joke: \(joke.id)")
                }
            }
            
            lastDocument = snapshot.documents.last
            hasMoreJokes = !snapshot.documents.isEmpty
            
            jokes.append(contentsOf: newJokes)
            LocalStorage.saveJokes(jokes)
            
            print("🟣 JokeService: Loaded \(newJokes.count) more jokes")
            
            // Начинаем предзагрузку следующей страницы
            Task {
                await preloadNextPage()
            }
        } catch {
            print("🟣 JokeService: Error loading more jokes: \(error)")
            self.error = error
        }
        
        isLoadingMore = false
    }
    
    // Метод для проверки необходимости предзагрузки
    func checkPreloadNeeded(currentIndex: Int) {
        if currentIndex >= jokes.count - preloadThreshold && !preloadedJokes.isEmpty {
            Task {
                await preloadNextPage()
            }
        }
    }
    
    private func fetchJokeWithPunchlines(from document: QueryDocumentSnapshot) async throws -> Joke? {
        do {
            var joke = try document.data(as: Joke.self)
            
            // Сначала пробуем загрузить панчлайны из кеша
            if let cachedPunchlines = LocalStorage.loadPunchlines(forJoke: joke.id) {
                print("🟣 JokeService: Using cached punchlines for joke: \(joke.id)")
                joke.punchlines = cachedPunchlines
                return joke
            }
            
            // Если в кеше нет, загружаем из Firebase
            print("🟣 JokeService: Loading punchlines from Firebase for joke: \(joke.id)")
            let punchlinesSnapshot = try await document.reference
                .collection("punchlines")
                .getDocuments()
            
            joke.punchlines = try punchlinesSnapshot.documents.compactMap { punchlineDoc in
                try punchlineDoc.data(as: Punchline.self)
            }
            
            // Сохраняем загруженные панчлайны в кеш
            LocalStorage.savePunchlines(joke.punchlines, forJoke: joke.id)
            
            print("🟣 JokeService: Successfully decoded joke: \(joke.id) with \(joke.punchlines.count) punchlines")
            return joke
        } catch {
            print("🟣 JokeService: Failed to decode joke from document \(document.documentID): \(error)")
            return nil
        }
    }
    
    // MARK: - Joke Operations
    func addJoke(user: User?, setup: String, punchline: String) async throws {
        if user == nil {
            alertMessage = "Необходимо войти в аккаунт"
            showAlert = true
            return
        }
        isLoading = true
        let joke = Joke(
            id: UUID().uuidString,
            setup: setup,
            punchlines: [Punchline(
                id: UUID().uuidString,
                text: punchline,
                status: "pending",
                authorId: user!.id
            )],
            status: "pending",
            authorId: user!.id,
            createdAt: Date()
        )
        
        let jokeRef = db.collection("jokes").document(joke.id)
        try await jokeRef.setData(from: joke)
        
        isLoading = false
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
    
    func toggleJokeReaction(_ jokeId: String, isLike: Bool, shouldAdd: Bool) async throws {
        print("🟣 JokeService: Toggling \(isLike ? "like" : "dislike") for joke \(jokeId)")
        let jokeRef = db.collection("jokes").document(jokeId)
        
        guard let index = jokes.firstIndex(where: { $0.id == jokeId }) else {
            print("🟣 JokeService: Joke not found in local state")
            return
        }
        
        var updates: [String: Any] = [:]
        
        if shouldAdd {
            if isLike {
                updates["likes"] = FieldValue.increment(Int64(1))
            } else {
                updates["dislikes"] = FieldValue.increment(Int64(1))
            }
        } else {
            if isLike {
                updates["likes"] = FieldValue.increment(Int64(-1))
            } else {
                updates["dislikes"] = FieldValue.increment(Int64(-1))
            }
        }
        
        // Update Firestore
        try await jokeRef.updateData(updates)
        
        // Update local state
        var newJoke = jokes[index]
        
        if shouldAdd {
            if isLike {
                newJoke.likes += 1
            } else {
                newJoke.dislikes += 1
            }
        } else {
            if isLike {
                newJoke.likes -= 1
            } else {
                newJoke.dislikes -= 1
            }
        }
        
        jokes[index] = newJoke
        LocalStorage.saveJokes(jokes)
    }
    
    func togglePunchlineReaction(_ jokeId: String, _ punchlineId: String, isLike: Bool, shouldAdd: Bool) async throws {
        print("🟣 JokeService: Toggling \(isLike ? "like" : "dislike") for punchline \(punchlineId)")
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
        guard let jokeIndex = jokes.firstIndex(where: { $0.id == jokeId }),
              let punchlineIndex = jokes[jokeIndex].punchlines.firstIndex(where: { $0.id == punchlineId }) else {
            print("🟣 JokeService: Punchline not found in local state")
            return
        }
        
        var updates: [String: Any] = [:]
        
        if shouldAdd {
            if isLike {
                updates["likes"] = FieldValue.increment(Int64(1))
            } else {
                updates["dislikes"] = FieldValue.increment(Int64(1))
            }
        } else {
            if isLike {
                updates["likes"] = FieldValue.increment(Int64(-1))
            } else {
                updates["dislikes"] = FieldValue.increment(Int64(-1))
            }
        }
        
        // Update Firestore
        try await punchlineRef.updateData(updates)
        
        // Update local state
        var newPunchline = jokes[jokeIndex].punchlines[punchlineIndex]
        
        if shouldAdd {
            if isLike {
                newPunchline.likes += 1
            } else {
                newPunchline.dislikes += 1
            }
        } else {
            if isLike {
                newPunchline.likes -= 1
            } else {
                newPunchline.dislikes -= 1
            }
        }
        
        jokes[jokeIndex].punchlines[punchlineIndex] = newPunchline
        LocalStorage.saveJokes(jokes)
    }
    
    // MARK: - Punchline Operations
    func addPunchline(toJokeId jokeId: String, text: String, authorId: String?) async throws {
        print("🟣 JokeService: Adding punchline to joke \(jokeId)")
        guard let authorId = authorId else {
            showAlert = true
            alertMessage = "Необходимо войти в аккаунт"
            return
        }
        isLoading = true
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
        isLoading = false
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
