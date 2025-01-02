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
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        contentView
    }
    
    var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(colorScheme == .dark ? .black : .white),
                Color.purple.opacity(0.2)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var contentView: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                if favouriteJokes.isEmpty {
                    emptyStateView
                } else {
                    jokeListView
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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
                        try await userService.updateUsername(user.username ?? "")
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
