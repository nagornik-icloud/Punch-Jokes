import Foundation
import FirebaseFirestore

@MainActor
class UserReactionsService: ObservableObject {
    private let db = Firestore.firestore()
    @Published private(set) var punchlineReactions: [String: String] = [:] // [punchlineId: "like"/"dislike"]
    @Published private(set) var jokeReactions: [String: String] = [:] // [jokeId: "like"/"dislike"]
    
    init() {
        loadFromUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        if let savedPunchlineReactions = UserDefaults.standard.dictionary(forKey: "UserPunchlineReactions") as? [String: String] {
            punchlineReactions = savedPunchlineReactions
            print("👍 UserReactionsService: Loaded \(savedPunchlineReactions.count) punchline reactions from UserDefaults")
        }
        
        if let savedJokeReactions = UserDefaults.standard.dictionary(forKey: "UserJokeReactions") as? [String: String] {
            jokeReactions = savedJokeReactions
            print("👍 UserReactionsService: Loaded \(savedJokeReactions.count) joke reactions from UserDefaults")
        }
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(punchlineReactions, forKey: "UserPunchlineReactions")
        UserDefaults.standard.set(jokeReactions, forKey: "UserJokeReactions")
    }
    
    func getCurrentPunchlineReaction(for punchlineId: String) -> String? {
        return punchlineReactions[punchlineId]
    }
    
    func getCurrentJokeReaction(for jokeId: String) -> String? {
        return jokeReactions[jokeId]
    }
    
    func syncWithFirestore(userId: String) async {
        do {
            let document = try await db.collection("user_reactions").document(userId).getDocument()
            if let data = document.data() {
                if let punchlineReactionsData = data["punchlineReactions"] as? [String: String] {
                    punchlineReactions = punchlineReactionsData
                    print("👍 UserReactionsService: Loaded \(punchlineReactionsData.count) punchline reactions from Firestore")
                }
                if let jokeReactionsData = data["jokeReactions"] as? [String: String] {
                    jokeReactions = jokeReactionsData
                    print("👍 UserReactionsService: Loaded \(jokeReactionsData.count) joke reactions from Firestore")
                }
                saveToUserDefaults()
            }
        } catch {
            print("👍 UserReactionsService: Error loading reactions from Firestore: \(error.localizedDescription)")
        }
    }
    
    func togglePunchlineReaction(userId: String, punchlineId: String, isLike: Bool) async throws -> (add: Bool, isLike: Bool) {
        let currentReaction = punchlineReactions[punchlineId]
        let newReaction = isLike ? "like" : "dislike"
        
        // Если текущая реакция такая же как новая - удаляем
        if currentReaction == newReaction {
            punchlineReactions.removeValue(forKey: punchlineId)
            try await updateFirestore(userId: userId, type: "punchline", id: punchlineId, reaction: nil)
            saveToUserDefaults()
            return (add: false, isLike: isLike)
        }
        
        // Добавляем новую реакцию
        punchlineReactions[punchlineId] = newReaction
        try await updateFirestore(userId: userId, type: "punchline", id: punchlineId, reaction: newReaction)
        saveToUserDefaults()
        return (add: true, isLike: isLike)
    }
    
    func toggleJokeReaction(userId: String, jokeId: String, isLike: Bool) async throws -> (add: Bool, isLike: Bool) {
        let currentReaction = jokeReactions[jokeId]
        let newReaction = isLike ? "like" : "dislike"
        
        // Если текущая реакция такая же как новая - удаляем
        if currentReaction == newReaction {
            jokeReactions.removeValue(forKey: jokeId)
            try await updateFirestore(userId: userId, type: "joke", id: jokeId, reaction: nil)
            saveToUserDefaults()
            return (add: false, isLike: isLike)
        }
        
        // Добавляем новую реакцию
        jokeReactions[jokeId] = newReaction
        try await updateFirestore(userId: userId, type: "joke", id: jokeId, reaction: newReaction)
        saveToUserDefaults()
        return (add: true, isLike: isLike)
    }
    
    private func updateFirestore(userId: String, type: String, id: String, reaction: String?) async throws {
        let userReactionsRef = db.collection("user_reactions").document(userId)
        
        if let reaction = reaction {
            // Добавляем реакцию
            try await userReactionsRef.setData([
                "\(type)Reactions": [id: reaction]
            ], merge: true)
        } else {
            // Удаляем реакцию
            try await userReactionsRef.updateData([
                "\(type)Reactions.\(id)": FieldValue.delete()
            ])
        }
    }
}
