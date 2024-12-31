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
    
    var body: some View {
        contentView
    }
    
    private var contentView: some View {
        NavigationView {
            ScrollView {
                if jokeService.allJokes.isEmpty {
                    emptyStateView
                } else {
                    jokeListView
                }
                Color.clear.frame(height: 50)
            }
            .navigationTitle("Все шутки")
            .refreshable {
                await jokeService.fetchJokes()
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
