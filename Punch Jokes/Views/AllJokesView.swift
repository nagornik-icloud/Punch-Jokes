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
                ScrollView {
                    if jokeService.allJokes.isEmpty {
                        if jokeService.isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            emptyStateView
                        }
                    } else {
                        jokeListView
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Все шутки")
                .refreshable {
                    Task {
                        await jokeService.fetchJokes()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Нет шуток для отображения")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Потяните вниз, чтобы обновить")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    private var jokeListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(jokeService.allJokes) { joke in
                JokeCard(joke: joke)
                    .padding(.horizontal)
            }
            Color.clear.frame(height: 50)
        }
        .padding(.vertical)
    }
}

#Preview {
    AllJokesView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
