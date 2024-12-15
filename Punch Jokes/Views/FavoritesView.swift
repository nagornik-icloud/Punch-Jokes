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
    
    @State private var selectedCardIndex: Int? = nil
    
    // Оптимизация для `favouriteJokes`
    var favouriteJokes: [Joke] {
        let favoriteIDs = jokeService.favoriteJokes.isEmpty ?
        (userService.currentUser?.favouriteJokesIDs ?? []) :
        jokeService.favoriteJokes
        return jokeService.allJokes.filter { favoriteIDs.contains($0.id ?? "") }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if favouriteJokes.isEmpty {
                    Text("У вас пока нет избранных шуток.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(favouriteJokes) { joke in
                            JokeCard(
                                joke: joke,
                                isExpanded: selectedCardIndex == favouriteJokes.firstIndex(where: { $0.id == joke.id }),
                                onTap: {
                                    if let index = favouriteJokes.firstIndex(where: { $0.id == joke.id }) {
                                        selectedCardIndex = (selectedCardIndex == index) ? nil : index
                                    }
                                }
                            )
                            .frame(height: 140)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Избранное")
        }
        .onAppear {
            syncroniseJokes()
        }
    }
    
    private func syncroniseJokes() {
        let local = jokeService.favoriteJokes
        let server = userService.currentUser?.favouriteJokesIDs ?? []
        if local == server {return}
        if local.count < server.count {
            jokeService.favoriteJokes = server
        } else {
            guard let user = userService.currentUser else { return }
            userService.currentUser?.favouriteJokesIDs = local
            userService.saveUserToFirestore(user) { _ in
            }
        }
    }
    
}

#Preview {
    TabBarView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
