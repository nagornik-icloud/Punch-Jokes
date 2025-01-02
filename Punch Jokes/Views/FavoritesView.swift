//
//  FavoritesView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 16.12.24..
//

import SwiftUI

struct FavoritesView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    
    var body: some View {
        NavigationView {
            Group {
                if let currentUser = userService.currentUser,
                   let favoriteIds = currentUser.favouriteJokesIDs {
                    if favoriteIds.isEmpty {
                        ContentUnavailableView("Нет избранных", 
                            systemImage: "heart",
                            description: Text("Добавьте шутки в избранное!")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(jokeService.jokes.filter { favoriteIds.contains($0.id) }) { joke in
                                    JokeCard(joke: joke)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    ContentUnavailableView("Войдите в аккаунт", 
                        systemImage: "person.crop.circle",
                        description: Text("Чтобы видеть избранные шутки")
                    )
                }
            }
            .navigationTitle("Избранное")
            .refreshable {
                Task {
//                    try? await userService.downloadUserFromFirestore()
//                    await userService.fetchAndUpdateUsers()
//                    await jokeService.fetchJokes()
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
