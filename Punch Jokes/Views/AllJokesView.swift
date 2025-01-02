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
    
    var body: some View {
        NavigationView {
            Group {
                if jokeService.jokes.isEmpty && jokeService.isLoading {
                    ProgressView()
                        .padding()
                } else if jokeService.jokes.isEmpty {
                    ContentUnavailableView("Нет шуток", 
                        systemImage: "text.bubble",
                        description: Text("Добавьте первую шутку!")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(jokeService.jokes) { joke in
                                JokeCard(joke: joke)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Все шутки")
            .refreshable {
                Task {
//                    await refreshJokes()
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
//            try await jokeService.fetchJokes()
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
