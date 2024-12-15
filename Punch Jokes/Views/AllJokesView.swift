//
//  AllJokesView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 16.12.24..
//

import SwiftUI

struct AllJokesView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @State private var selectedCardIndex: Int? = nil
//    @State private var jokes = [Joke]()
    private var jokes: [Joke] {
        jokeService.allJokes
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if jokes.isEmpty {
                    Text("Нет шуток для отображения.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(jokes) { joke in
                            JokeCard(
                                joke: joke,
                                isExpanded: selectedCardIndex == jokes.firstIndex(where: { $0.id == joke.id }),
                                onTap: {
                                    if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                                            selectedCardIndex = (selectedCardIndex == index) ? nil : index
                                    }
                                }
                            )
                            .frame(height: 140) // Убедимся, что карточки имеют правильную высоту для кликов
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Все шутки")  // Заголовок для экрана
            
            
            
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
