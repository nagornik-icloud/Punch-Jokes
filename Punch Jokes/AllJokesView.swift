//
//  AllJokesView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 16.12.24..
//

import SwiftUI

struct AllJokesView: View {
    let jokes: [Joke]
    @Binding var favorites: Set<Joke>

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                if jokes.isEmpty {
                    Text("Нет шуток для отображения.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(jokes) { joke in
                            JokeCard(joke: joke, favorites: $favorites)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Все шутки")
        }
    }
}
