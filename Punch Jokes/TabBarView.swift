//
//  tabBarView.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI

struct TabBarView: View {
    @State private var favorites: Set<Joke> = []
    @State private var jokes: [Joke] = []

    let jokeService = JokeService()

    var body: some View {
        TabView {
            // Вкладка "Все шутки"
            AllJokesView(jokes: jokes, favorites: $favorites)
                .tabItem {
                    Image(systemName: "text.bubble")
                    Text("Все шутки")
                }

            // Вкладка "Избранное"
            FavoritesView(favorites: $favorites)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Избранное")
                }

            // Вкладка "Добавить шутку / мои шутки"
            MyJokesView()
                .tabItem {
                    Image(systemName: "plus.square")
                    Text("Мои шутки")
                }

            // Вкладка "Настройки"
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Настройки")
                }
        }
        .onAppear {
            jokeService.fetchJokes { fetchedJokes in
//                print("Получены шутки: \(fetchedJokes)")  // Выводим шутки в консоль
                self.jokes = fetchedJokes
            }
        }
    }
}


#Preview {
    TabBarView()
}
