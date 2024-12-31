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
    @EnvironmentObject var appService: AppService
    
    var body: some View {
        contentView
    }
    
    private var contentView: some View {
        NavigationView {
            Group {
                if favouriteJokes.isEmpty {
                    emptyStateView
                } else {
                    jokeListView
                }
            }
            .navigationTitle("Избранное")
        }
        .onAppear {
            syncroniseJokes()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("У вас пока нет избранных шуток")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Добавляйте понравившиеся шутки в избранное, нажимая на сердечко")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var jokeListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(favouriteJokes) { joke in
                    JokeCard(joke: joke)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
            Color.clear.frame(height: 50)
        }
    }
    
    // Оптимизация для `favouriteJokes`
    var favouriteJokes: [Joke] {
        let favoriteIDs = jokeService.favoriteJokes.isEmpty ?
        (userService.currentUser?.favouriteJokesIDs ?? []) :
        jokeService.favoriteJokes
        return jokeService.allJokes.filter { favoriteIDs.contains($0.id ?? "") }
    }
    
    private func syncroniseJokes() {
        let local = jokeService.favoriteJokes
        let server = userService.currentUser?.favouriteJokesIDs ?? []
        
        // Синхронизируем локальные избранные с серверными
        if local != server {
            if var user = userService.currentUser {
                user.favouriteJokesIDs = local
                Task {
                    do {
                        try await userService.saveUserToFirestore(user)
                        // После успешного сохранения на сервере, обновляем кеш
                        userService.saveUserToCache(user)
                    } catch {
                        print("Error syncing favorites: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
