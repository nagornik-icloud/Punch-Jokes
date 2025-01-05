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
                            ForEach(sortedJokes) { joke in
                                JokeCard(joke: joke)
                                    .padding(.horizontal)
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
