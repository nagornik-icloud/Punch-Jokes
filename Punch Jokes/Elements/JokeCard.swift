//
//  JokeCard.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore

struct JokeCard: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var localFavorites = LocalFavoritesService()
    
    let joke: Joke
    var showAuthor: Bool = true
    
    @State private var isExpanded = false
    @State private var isSavingFavorite = false
    @State private var isUpdatingReaction = false
    @State private var selectedPunchlineId: String?
    @State var img = UIImage()
    
    private var authorUsername: String {
        if userService.isLoading {
            return "Загрузка..."
        }
        return userService.userNameCache[joke.authorId] ?? "Пользователь"
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var isFavorite: Bool {
        if let currentUser = userService.currentUser {
            return currentUser.favouriteJokesIDs?.contains(joke.id) ?? false
        } else {
            return localFavorites.contains(joke.id)
        }
    }
    
    var body: some View {
        ZStack {
            mainCard
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .onAppear {
            // Увеличиваем счетчик просмотров при появлении карточки
            Task {
                try? await jokeService.incrementJokeViews(joke.id)
            }
        }
    }
    
    private var authorImage: some View {
        Group {
            ZStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                
                if let image = jokeService.authorImages[joke.authorId] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if jokeService.isLoadingImages {
                    ProgressView()
                        .frame(width: 30, height: 30)
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .animation(.easeInOut, value: jokeService.authorImages[joke.authorId] != nil)
        .animation(.easeInOut, value: jokeService.isLoadingImages)
    }
    
    var jokeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Setup
            Text(joke.setup)
                .font(.body)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .lineSpacing(4)
            
            // Статистика шутки
            HStack(spacing: 16) {
                Label("\(joke.views)", systemImage: "eye")
                    .foregroundColor(.gray)
                
                Button(action: {
                    guard !isUpdatingReaction else { return }
                    Task {
                        isUpdatingReaction = true
                        defer { isUpdatingReaction = false }
                        try? await jokeService.toggleJokeReaction(joke.id, isLike: true)
                    }
                }) {
                    Label("\(joke.likes)", systemImage: joke.likes > 0 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(joke.likes > 0 ? .blue : .gray)
                        .opacity(isUpdatingReaction ? 0.5 : 1.0)
                }
                
                Button(action: {
                    guard !isUpdatingReaction else { return }
                    Task {
                        isUpdatingReaction = true
                        defer { isUpdatingReaction = false }
                        try? await jokeService.toggleJokeReaction(joke.id, isLike: false)
                    }
                }) {
                    Label("\(joke.dislikes)", systemImage: joke.dislikes > 0 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(joke.dislikes > 0 ? .red : .gray)
                        .opacity(isUpdatingReaction ? 0.5 : 1.0)
                }
            }
            .font(.caption)
            
            if isExpanded {
                // Панчлайны
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(joke.punchlines) { punchline in
                        PunchlineView(punchline: punchline, jokeId: joke.id)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    var heartIcon: some View {
        Button {
            if !isSavingFavorite {
                toggleFavorite()
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundColor(isFavorite ? .red : .gray)
                .opacity(isSavingFavorite ? 0.5 : 1.0)
        }
        .disabled(isSavingFavorite)
    }
    
    var authorAndDate: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(authorUsername)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(joke.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.8))
        }
    }
    
    var shareButton: some View {
        Button(action: shareJoke) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
    }
    
    private var mainCard: some View {
        HStack {
            VStack(alignment: .leading) {
                jokeContent
                Spacer()
                HStack {
                    authorImage
                    authorAndDate
                }
            }
            Spacer()
            VStack {
                heartIcon
                Spacer()
                shareButton
            }
            .padding(4)
        }
        .padding()
        .background(Color.gray.opacity(0.001))
        .onTapGesture {
            hapticFeedback()
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func toggleFavorite() {
        guard !isSavingFavorite else { return }
        isSavingFavorite = true
        
        Task {
            do {
                if let currentUser = userService.currentUser {
                    // Для авторизованного пользователя
                    var favorites = currentUser.favouriteJokesIDs ?? []
                    if favorites.contains(joke.id) {
                        favorites.removeAll { $0 == joke.id }
                    } else {
                        favorites.append(joke.id)
                    }
                    currentUser.favouriteJokesIDs = favorites
                    try await userService.saveUserToFirestore()
                } else {
                    // Для неавторизованного пользователя
                    if localFavorites.contains(joke.id) {
                        localFavorites.removeFavoriteJoke(joke.id)
                    } else {
                        localFavorites.addFavoriteJoke(joke.id)
                    }
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
            
            isSavingFavorite = false
        }
    }
    
    private func shareJoke() {
        let textToShare = """
        Setup: \(joke.setup)
        Punchlines:
        \(joke.punchlines.map { "- \($0.text)" }.joined(separator: "\n"))
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [textToShare],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// Отдельное view для панчлайна
struct PunchlineView: View {
    let punchline: Punchline
    let jokeId: String
    @EnvironmentObject var jokeService: JokeService
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(punchline.text)
                .font(.headline)
                .foregroundColor(.purple)
                .fontWeight(.medium)
                .lineSpacing(4)
            
            HStack(spacing: 16) {
                Button(action: {
                    guard !isUpdating else { return }
                    toggleReaction(isLike: true)
                }) {
                    Label("\(punchline.likes)", systemImage: punchline.likes > 0 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(punchline.likes > 0 ? .blue : .gray)
                        .opacity(isUpdating ? 0.5 : 1.0)
                }
                
                Button(action: {
                    guard !isUpdating else { return }
                    toggleReaction(isLike: false)
                }) {
                    Label("\(punchline.dislikes)", systemImage: punchline.dislikes > 0 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(punchline.dislikes > 0 ? .red : .gray)
                        .opacity(isUpdating ? 0.5 : 1.0)
                }
            }
            .font(.caption)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func toggleReaction(isLike: Bool) {
        isUpdating = true
        errorMessage = nil
        
        Task {
            do {
                try await jokeService.togglePunchlineReaction(jokeId, punchline.id, isLike: isLike)
            } catch {
                errorMessage = "Не удалось обновить реакцию"
                print("Error toggling reaction: \(error)")
            }
            isUpdating = false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Full Screen Preview
#Preview("Full Screen") {
    TabBarView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
