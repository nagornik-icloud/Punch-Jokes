//
//  JokeCardView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI

struct JokeCard: View {
    let joke: Joke
    @State private var isFlipped: Bool = false
    @Binding var favorites: Set<Joke>  // Используем Set вместо массива

    var isFavorite: Bool {
        favorites.contains(joke)  // Проверяем, содержится ли шутка в Set
    }

    var body: some View {
        ZStack {
            // Задняя сторона (панчлайн)
            if isFlipped {
                VStack {
                    Text(joke.punchline)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom))
                .cornerRadius(16)
                .shadow(radius: 4)
            } else {
                // Передняя сторона (затравка)
                VStack(alignment: .leading) {
                    HStack {
                        Spacer()
                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .gray)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .padding([.top, .trailing], 8)
                    }
                    Spacer()
                    Text(joke.setup)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .shadow(radius: 4)
            }
        }
        .frame(height: 140) // Высота карточки
        .onTapGesture {
            withAnimation(.easeInOut) {
                isFlipped.toggle()
            }
        }
    }

    // Обработка добавления/удаления из избранного
    private func toggleFavorite() {
        if isFavorite {
            favorites.remove(joke)  // Удаляем из Set
        } else {
            favorites.insert(joke)  // Добавляем в Set
        }
    }
}
