import Foundation
import FirebaseFirestore

@MainActor
class UserReactionsService: ObservableObject {
    private let db = Firestore.firestore()
    @Published private(set) var reactions: [String: String] = [:] // [punchlineId: "like"/"dislike"]
    
    init() {
        loadFromUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        if let savedReactions = UserDefaults.standard.dictionary(forKey: "UserPunchlineReactions") as? [String: String] {
            reactions = savedReactions
            print("👍 UserReactionsService: Loaded \(savedReactions.count) reactions from UserDefaults")
        }
    }
    
    func saveToUserDefaults() {
        UserDefaults.standard.set(reactions, forKey: "UserPunchlineReactions")
    }
    
    func getCurrentReaction(for punchlineId: String) -> String? {
        return reactions[punchlineId]
    }
    
    func syncWithFirestore(userId: String) async {
        do {
            let document = try await db.collection("user_reactions").document(userId).getDocument()
            if let data = document.data(),
               let firestoreReactions = data["reactions"] as? [String: String] {
                reactions = firestoreReactions
                print("👍 UserReactionsService: Loaded \(firestoreReactions.count) reactions from Firestore")
                saveToUserDefaults()
            }
        } catch {
            print("👍 UserReactionsService: Error loading reactions from Firestore: \(error.localizedDescription)")
        }
    }
    
    func toggleReaction(userId: String, punchlineId: String, isLike: Bool) async throws -> (add: Bool, isLike: Bool) {
        let currentReaction = reactions[punchlineId]
        let newReaction = isLike ? "like" : "dislike"
        
        // Если текущая реакция такая же как новая - удаляем
        if currentReaction == newReaction {
            reactions.removeValue(forKey: punchlineId)
            try await removeReactionFromFirestore(userId: userId, punchlineId: punchlineId)
            saveToUserDefaults()
            return (add: false, isLike: isLike)
        }
        
        // Добавляем новую реакцию
        reactions[punchlineId] = newReaction
        try await saveReactionToFirestore(userId: userId, punchlineId: punchlineId, reaction: newReaction)
        saveToUserDefaults()
        return (add: true, isLike: isLike)
    }
    
    private func saveReactionToFirestore(userId: String, punchlineId: String, reaction: String) async throws {
        let userReactionsRef = db.collection("user_reactions").document(userId)
        try await userReactionsRef.setData([
            "reactions": [punchlineId: reaction]
        ], merge: true)
    }
    
    private func removeReactionFromFirestore(userId: String, punchlineId: String) async throws {
        let userReactionsRef = db.collection("user_reactions").document(userId)
        try await userReactionsRef.updateData([
            "reactions.\(punchlineId)": FieldValue.delete()
        ])
    }
}
