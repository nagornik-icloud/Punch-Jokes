//
//  JokeCard.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI
import FirebaseFirestore

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
        .frame(width: 40, height: 40)
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
        VStack(alignment: .leading, spacing: 12) {
            if showAuthor {
                HStack {
                    authorImage
                    VStack(alignment: .leading) {
                        Text(authorUsername)
                            .font(.headline)
                            .redacted(reason: userService.isLoading ? .placeholder : [])
                        
                        Text(dateFormatter.string(from: joke.createdAt ?? Date()))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
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
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(joke.setup)
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.leading)
                
                if showPunchline {
                    if isExpanded {
                        Text(joke.punchline)
                            .font(.body)
                            .foregroundColor(.purple)
                            .multilineTextAlignment(.leading)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            if showPunchline {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isExpanded.toggle()
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
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

//#Preview {
//    let userService = UserService()
//    let jokeService = JokeService()
//    let joke = Joke(id: "test", authorId: "test", setup: "Why did the chicken cross the road?", punchline: "To get to the other side!", createdAt: Date())
//
//    // Добавляем тестовые данные в кэш
//    userService.userNameCache["test"] = "Test User"
//
//    return JokeCard(joke: joke)
//        .environmentObject(userService)
//        .environmentObject(jokeService)
//}
