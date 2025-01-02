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
    @StateObject private var localFavorites = LocalFavoritesService()
    
    var favoriteJokes: [Joke] {
        let jokes: [Joke]
        if let currentUser = userService.currentUser,
           let favoriteIds = currentUser.favouriteJokesIDs {
            jokes = jokeService.jokes.filter { favoriteIds.contains($0.id) }
        } else {
            jokes = jokeService.jokes.filter { localFavorites.contains($0.id) }
        }
        return jokes.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if favoriteJokes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding(.top, 100)
                        
                        Text("Нет избранных шуток")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        if userService.currentUser == nil {
                            Text("Войдите в аккаунт, чтобы синхронизировать избранное")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(favoriteJokes) { joke in
                            JokeCard(joke: joke)
                        }
                    }
                    .padding()
                }
                Color.clear
                    .frame(height: 100)
            }
            .appBackground()
            .navigationTitle("Избранное")
            .refreshable {
                Task {
                    await jokeService.loadInitialData()
                    await userService.loadInitialData()
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
