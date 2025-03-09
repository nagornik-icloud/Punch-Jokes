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
            print("👍 [\(Date())] UserReactionsService: Loaded \(savedPunchlineReactions.count) punchline reactions from UserDefaults")
        }
        
        if let savedJokeReactions = UserDefaults.standard.dictionary(forKey: "UserJokeReactions") as? [String: String] {
            jokeReactions = savedJokeReactions
            print("👍 [\(Date())] UserReactionsService: Loaded \(savedJokeReactions.count) joke reactions from UserDefaults")
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
                    print("👍 [\(Date())] UserReactionsService: Loaded \(punchlineReactionsData.count) punchline reactions from Firestore")
                }
                if let jokeReactionsData = data["jokeReactions"] as? [String: String] {
                    jokeReactions = jokeReactionsData
                    print("👍 [\(Date())] UserReactionsService: Loaded \(jokeReactionsData.count) joke reactions from Firestore")
                }
                saveToUserDefaults()
            }
        } catch {
            print("👍 [\(Date())] UserReactionsService: Error loading reactions from Firestore: \(error.localizedDescription)")
        }
    }
    
    func toggleReaction(userId: String, id: String, isLike: Bool, type: String) async throws -> (add: Bool, isLike: Bool) {
        var currentReaction: String?
        var reactions: [String: String]
        
        switch type {
        case "punchline":
            currentReaction = punchlineReactions[id]
            reactions = punchlineReactions
        case "joke":
            currentReaction = jokeReactions[id]
            reactions = jokeReactions
        default:
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid reaction type"])
        }
        
        let newReaction = isLike ? "like" : "dislike"
        
        if currentReaction == newReaction {
            if type == "punchline" {
                punchlineReactions.removeValue(forKey: id)
            } else if type == "joke" {
                jokeReactions.removeValue(forKey: id)
            }
            try await updateFirestore(userId: userId, type: type, id: id, reaction: nil)
            saveToUserDefaults()
            return (add: false, isLike: isLike)
        }
        
        if type == "punchline" {
            punchlineReactions[id] = newReaction
        } else if type == "joke" {
            jokeReactions[id] = newReaction
        }
        try await updateFirestore(userId: userId, type: type, id: id, reaction: newReaction)
        saveToUserDefaults()
        return (add: true, isLike: isLike)
    }
    
    private func updateFirestore(userId: String, type: String, id: String, reaction: String?) async throws {
        let userReactionsRef = db.collection("user_reactions").document(userId)
        
        if let reaction = reaction {
            try await userReactionsRef.setData([
                "\(type)Reactions": [id: reaction]
            ], merge: true)
        } else {
            try await userReactionsRef.updateData([
                "\(type)Reactions.\(id)": FieldValue.delete()
            ])
        }
    }
}
