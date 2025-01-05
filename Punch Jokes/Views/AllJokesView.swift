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
    
    @Environment(\.colorScheme) var colorScheme
    
    @State var showError = false
    @State var errorMessage = ""
    
    var sortedJokes: [Joke] {
        jokeService.jokes
            .filter { $0.status == "approved" }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if jokeService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Загружаем шутки...")
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else if sortedJokes.isEmpty {
                    ContentUnavailableView("Нет шуток",
                        systemImage: "text.bubble",
                        description: Text("Пока нет одобренных шуток")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(sortedJokes.enumerated()), id: \.element.id) { index, joke in
                                JokeCard(joke: joke)
                                    .padding(.horizontal)
                                    .onAppear {
                                        // Проверяем, нужно ли загрузить следующую страницу
                                        if index == sortedJokes.count - 5 {
                                            Task {
                                                await jokeService.loadMoreJokes()
                                            }
                                        }
                                        // Проверяем, нужно ли начать предзагрузку
                                        jokeService.checkPreloadNeeded(currentIndex: index)
                                    }
                            }
                            
                            if jokeService.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(.vertical)
                        Color.clear
                            .frame(height: 100)
                    }
                    .appBackground()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Все шутки")
            .refreshable {
                Task {
                    await refreshJokes()
                }
            }
            .onAppear {
                print("AllJokesView appeared, jokes count: \(jokeService.jokes.count)")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    func refreshJokes() async {
        do {
            print("Refreshing jokes...")
            await jokeService.loadInitialData()
            await userService.loadInitialData()
            print("Jokes refreshed, count: \(jokeService.jokes.count)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    AllJokesView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
