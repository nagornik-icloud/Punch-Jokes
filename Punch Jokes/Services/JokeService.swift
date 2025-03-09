
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
    
    private var userReactions: [String: String] = [:]
    private var lastDocument: QueryDocumentSnapshot?
    private var preloadedJokes: [Joke] = []
    private var isPreloading = false
    private var loadedImagesTimestamps: [String: Date] = [:]
    private let preloadThreshold = 5
    
    init() {
        print("🟣 JokeService: Initializing...")
        Task {
            await loadData()
        }
    }
    
    func loadData() async {
        isLoading = true
        loadCachedData()
        do {
            let snapshot = try await db.collection("jokes")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .getDocuments()
            
            var fetchedJokes: [Joke] = []
            for document in snapshot.documents {
                if let joke = try? await fetchJokeWithPunchlines(from: document) {
                    fetchedJokes.append(joke)
                }
            }
            
            if jokes != fetchedJokes {
                lastDocument = snapshot.documents.last
                hasMoreJokes = !snapshot.documents.isEmpty
                jokes = fetchedJokes
                LocalStorage.saveJokes(fetchedJokes)
                
                Task {
                    await preloadNextPage()
                }
                
                isLoadingImages = true
                await loadAllAuthorImages()
                isLoadingImages = false
            }
        } catch {
            handleError(error, message: "Error loading initial data")
        }
        isLoading = false
    }
    
    private func loadCachedData() {
        if let savedJokes = LocalStorage.loadJokes() {
            jokes = savedJokes
        }
        
        let uniqueAuthors = Set(jokes.map { $0.authorId })
        for authorId in uniqueAuthors {
            if let savedImage = LocalStorage.loadImage(forUserId: authorId) {
                authorImages[authorId] = savedImage
            }
        }
        
        isLoading = jokes.isEmpty
    }
    
    private func loadAllAuthorImages() async {
        let uniqueAuthors = Set(jokes.map { $0.authorId })
        
        for authorId in uniqueAuthors {
            let lastUpdate = loadedImagesTimestamps[authorId] ?? .distantPast
            let shouldUpdate = Date().timeIntervalSince(lastUpdate) > 3600
            
            if !shouldUpdate, let cachedImage = authorImages[authorId] {
                continue
            }
            
            if let image = try? await loadAuthorImage(for: authorId) {
                await MainActor.run {
                    authorImages[authorId] = image
                    loadedImagesTimestamps[authorId] = Date()
                }
                LocalStorage.saveImage(image, forUserId: authorId)
                UserDefaults.standard.set(loadedImagesTimestamps, forKey: "AuthorImagesTimestamps")
            }
        }
    }
    
    private func loadAuthorImage(for userId: String) async throws -> UIImage? {
        let storageRef = storage.reference().child("user_images/\(userId).jpg")
        
        do {
            let url = try await storageRef.downloadURL()
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            return optimizeImage(image)
        } catch {
            handleError(error, message: "Error loading image for author: \(userId)")
            return nil
        }
    }
    
    private func optimizeImage(_ image: UIImage, maxSize: CGFloat = 200) -> UIImage {
        let originalSize = max(image.size.width, image.size.height)
        if originalSize <= maxSize {
            return image
        }
        
        let ratio = maxSize / originalSize
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func preloadNextPage() async {
        guard !isPreloading, hasMoreJokes, let lastDocument = lastDocument else { return }
        
        isPreloading = true
        
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
                }
            }
            
            preloadedJokes = newJokes
        } catch {
            handleError(error, message: "Error preloading jokes")
        }
        
        isPreloading = false
    }
    
    func loadMoreJokes() async {
        guard !isLoadingMore, hasMoreJokes else { return }
        
        isLoadingMore = true
        
        if !preloadedJokes.isEmpty {
            jokes.append(contentsOf: preloadedJokes)
            
            if let lastJoke = preloadedJokes.last,
               let snapshot = try? await db.collection("jokes")
                .whereField("id", isEqualTo: lastJoke.id)
                .getDocuments(),
               let lastDoc = snapshot.documents.first {
                lastDocument = lastDoc
            }
            
            preloadedJokes = []
            Task {
                await preloadNextPage()
            }
            
            isLoadingMore = false
            return
        }
        
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
                }
            }
            
            lastDocument = snapshot.documents.last
            hasMoreJokes = !snapshot.documents.isEmpty
            
            jokes.append(contentsOf: newJokes)
            LocalStorage.saveJokes(jokes)
            
            Task {
                await preloadNextPage()
            }
        } catch {
            handleError(error, message: "Error loading more jokes")
        }
        
        isLoadingMore = false
    }
    
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
            
            if let cachedPunchlines = LocalStorage.loadPunchlines(forJoke: joke.id) {
                joke.punchlines = cachedPunchlines
                return joke
            }
            
            let punchlinesSnapshot = try await document.reference
                .collection("punchlines")
                .getDocuments()
            
            joke.punchlines = try punchlinesSnapshot.documents.compactMap { punchlineDoc in
                try punchlineDoc.data(as: Punchline.self)
            }
            
            LocalStorage.savePunchlines(joke.punchlines, forJoke: joke.id)
            return joke
        } catch {
            handleError(error, message: "Failed to decode joke from document \(document.documentID)")
            return nil
        }
    }
    
    // MARK: - Joke Operations
    func addJoke(user: User?, setup: String, punchline: String) async throws {
        guard let user = user else {
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
                authorId: user.id
            )],
            status: "pending",
            authorId: user.id,
            createdAt: Date()
        )
        
        let jokeRef = db.collection("jokes").document(joke.id)
        try await jokeRef.setData(from: joke)
        
        jokes.insert(joke, at: 0)
        LocalStorage.saveJokes(jokes)
        isLoading = false
    }
    
    func incrementJokeViews(_ jokeId: String) async throws {
        let jokeRef = db.collection("jokes").document(jokeId)
        
        try await jokeRef.updateData([
            "views": FieldValue.increment(Int64(1))
        ])
        
        if let index = jokes.firstIndex(where: { $0.id == jokeId }) {
            jokes[index].views += 1
            LocalStorage.saveJokes(jokes)
        }
    }
    
    func toggleJokeReaction(jokeId: String, isLike: Bool, shouldAdd: Bool) async throws {
        let jokeRef = db.collection("jokes").document(jokeId)
        
        guard let index = jokes.firstIndex(where: { $0.id == jokeId }) else {
            return
        }
        
        var updates: [String: Any] = [:]
        
        if shouldAdd {
            updates[isLike ? "likes" : "dislikes"] = FieldValue.increment(Int64(1))
        } else {
            updates[isLike ? "likes" : "dislikes"] = FieldValue.increment(Int64(-1))
        }
        
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
        try await jokeRef.updateData(updates)
    }
    
    func togglePunchlineReaction(_ jokeId: String, _ punchlineId: String, isLike: Bool, shouldAdd: Bool) async throws {
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
        guard let jokeIndex = jokes.firstIndex(where: { $0.id == jokeId }),
              let punchlineIndex = jokes[jokeIndex].punchlines.firstIndex(where: { $0.id == punchlineId }) else {
            return
        }
        
        var updates: [String: Any] = [:]
        
        if shouldAdd {
            updates[isLike ? "likes" : "dislikes"] = FieldValue.increment(Int64(1))
        } else {
            updates[isLike ? "likes" : "dislikes"] = FieldValue.increment(Int64(-1))
        }
        
        try await punchlineRef.updateData(updates)
        
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
        
        if let index = jokes.firstIndex(where: { $0.id == jokeId }) {
            jokes[index].punchlines.append(punchline)
            LocalStorage.saveJokes(jokes)
        }
        isLoading = false
    }
    
    func updatePunchlineStatus(_ jokeId: String, _ punchlineId: String, status: String) async throws {
        let punchlineRef = db.collection("jokes").document(jokeId).collection("punchlines").document(punchlineId)
        
        try await punchlineRef.updateData([
            "status": status
        ])
        
        if let jokeIndex = jokes.firstIndex(where: { $0.id == jokeId }),
           let punchlineIndex = jokes[jokeIndex].punchlines.firstIndex(where: { $0.id == punchlineId }) {
            jokes[jokeIndex].punchlines[punchlineIndex].status = status
            LocalStorage.saveJokes(jokes)
        }
    }
    
    // MARK: - Helper Methods
    func getJokesByAuthor(_ authorId: String) -> [Joke] {
        return jokes.filter { $0.authorId == authorId }
    }
    
    func getPunchlines(for jokeId: String, withStatus status: String? = nil) -> [Punchline] {
        guard let joke = jokes.first(where: { $0.id == jokeId }) else {
            return []
        }
        
        if let status = status {
            return joke.punchlines.filter { $0.status == status }
        }
        
        return joke.punchlines
    }
    
    func uploadAuthorImage(_ image: UIImage, userId: String) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        _ = try await storageRef.putDataAsync(imageData)
        
        authorImages[userId] = image
        LocalStorage.saveImage(image, forUserId: userId)
    }
    
    func reloadAuthorImage(for userId: String) async {
        guard authorImages[userId] == nil && !loadedImagesTimestamps.keys.contains(userId) else {
            return
        }
        
        do {
            if let image = try await loadAuthorImage(for: userId) {
                authorImages[userId] = image
                loadedImagesTimestamps[userId] = Date()
                LocalStorage.saveImage(image, forUserId: userId)
            }
        } catch {
            handleError(error, message: "Error reloading image for author: \(userId)")
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error, message: String) {
        print("🟣 JokeService: \(message) - \(error)")
        self.error = error
        alertMessage = message
        showAlert = true
    }
}
