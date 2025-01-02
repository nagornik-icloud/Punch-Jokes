//import SwiftUI
//import FirebaseFirestore
//
//struct FavoriteSyncView: View {
//    @EnvironmentObject var userService: UserService
//    @EnvironmentObject var jokeService: JokeService
//    
//    var body: some View {
//        VStack {
//            if let user = userService.currentUser,
//               let serverFavorites = user.favouriteJokesIDs {
//                let localFavorites = jokeService.favoriteJokes
//                
//                if localFavorites.count != serverFavorites.count {
//                    Text("Your favorites are out of sync!")
//                        .foregroundColor(.red)
//                    
//                    Button("Sync Now") {
//                        syncFavorites(user: user, local: localFavorites, server: serverFavorites)
//                    }
//                    .buttonStyle(.bordered)
//                }
//            }
//        }
//    }
//    
//    private func syncFavorites(user: User, local: [String], server: [String]) {
//        var updatedUser = user
//        
//        if local.count > server.count {
//            updatedUser.favouriteJokesIDs = local
//        } else {
//            jokeService.favoriteJokes = server
//        }
//        
//        Task {
//            try? await userService.updateUserProfile(updatedUser)
//        }
//    }
//}
