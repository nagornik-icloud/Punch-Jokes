//
//  FavoritesView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 16.12.24..
//

import SwiftUI

struct FavoritesView: View {
    @Binding var favorites: Set<Joke>  // Используем Set вместо массива

    var body: some View {
        NavigationView {
            if favorites.isEmpty {
                Text("У вас пока нет избранных шуток.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(Array(favorites), id: \.id) { joke in  // Конвертируем Set в массив
                            JokeCard(joke: joke, favorites: $favorites)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Избранное")
            }
        }
    }
}
