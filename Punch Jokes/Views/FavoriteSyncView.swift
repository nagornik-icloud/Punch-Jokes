import SwiftUI
import FirebaseFirestore

struct FavoriteSyncView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    
    var body: some View {
        EmptyView()
            .onChange(of: jokeService.favoriteJokes) { newValue in
                syncFavorites(newValue)
            }
    }
    
    private func syncFavorites(_ favorites: [String]) {
        guard let userId = userService.currentUser?.id else { return }
        
        Task {
            do {
                try await jokeService.db.collection("users").document(userId).updateData([
                    "favouriteJokesIDs": favorites
                ])
            } catch {
                print("Error syncing favorites: \(error)")
            }
        }
    }
}
