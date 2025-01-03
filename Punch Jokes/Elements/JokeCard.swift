//
//  JokeCard.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI

struct JokeCard: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var localFavorites = LocalFavoritesService()
    
    let joke: Joke
    var showAuthor: Bool = true
    var showPunchline: Bool = true
    
    @State private var isExpanded = false
    @State private var isSavingFavorite = false
    @State var img = UIImage()
    
    @State private var isShowingPunchline = false
    @State private var offset: CGFloat = 0
    @State private var degrees: Double = 0
    
    private var authorUsername: String {
        if userService.isLoading {
            return "Загрузка..."
        }
        return userService.userNameCache[joke.authorId] ?? "Пользователь"
    }
    
    private var authorImage: some View {
        Group {
            if jokeService.isLoading {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else if let image = jokeService.authorImages[joke.authorId] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .animation(.easeInOut, value: jokeService.authorImages[joke.authorId] != nil)
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
            // Основная карточка
            mainCard
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingPunchline)
    }
    
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // Основной текст шутки
            HStack {
                Text(isShowingPunchline ? joke.punchline : joke.setup)
                    .font(isShowingPunchline ? .headline : .body)
                    .foregroundColor(isShowingPunchline ? .purple : .primary)
                    .fontWeight(.medium)
                    .lineSpacing(4)
                    .padding(.bottom, 4)
                
                Spacer()
                
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
            
            HStack(alignment: .center) {
                
                authorImage
                
                // Метаданные (автор и дата)
                VStack(alignment: .leading, spacing: 4) {
                    let author = authorUsername
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let date = joke.createdAt {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Кнопка поделиться
                Button(action: shareJoke) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(content: {
            Color.gray.opacity(0.0001)
        })
        .onTapGesture {
            hapticFeedback()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isShowingPunchline.toggle()
            }
        }
        
    }
    
    private var punchlineCard: some View {
        VStack(alignment: .leading) {
            Text(joke.punchline)
                .font(.body)
                .fontWeight(.medium)
                .lineSpacing(4)
                .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func shareJoke() {
        let textToShare = "\(joke.setup)\n\n\(joke.punchline)"
        let activityVC = UIActivityViewController(
            activityItems: [textToShare],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func toggleFavorite() {
        print("🎯 Toggling favorite for joke: \(joke.id)")
        if let currentUser = userService.currentUser {
            print("🎯 User is logged in, using server storage")
            // Для авторизованного пользователя
            var favorites = currentUser.favouriteJokesIDs ?? []
            if favorites.contains(joke.id) {
                favorites.removeAll { $0 == joke.id }
            } else {
                favorites.append(joke.id)
            }
            currentUser.favouriteJokesIDs = favorites
            saveFavorites()
        } else {
            print("🎯 User is not logged in, using local storage")
            // Для неавторизованного пользователя
            if localFavorites.contains(joke.id) {
                localFavorites.removeFavoriteJoke(joke.id)
            } else {
                localFavorites.addFavoriteJoke(joke.id)
            }
        }
    }
    
    private func saveFavorites() {
        guard !isSavingFavorite else { return }
        isSavingFavorite = true
        
        Task {
            if let user = userService.currentUser {
                do {
                    try await userService.saveUserToFirestore()
                } catch {
                    print("Error saving favorites: \(error)")
                }
            }
            isSavingFavorite = false
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

#Preview {
    TabBarView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
