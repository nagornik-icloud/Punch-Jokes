//
//  JokeCard.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI
import FirebaseStorage

struct JokeCard: View {
    let joke: Joke
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    
    @State private var authorImage: UIImage?
    @State private var isLoading = false
    @State private var isExpanded = false
    @State private var isFavorite = false
    @State private var authorUser: User?
    @State private var showShareSheet = false
    @State private var punchlineOffset: CGSize = .zero
    @State private var punchlineRotation: Double = -15
    
    var body: some View {
        ZStack {
            // Основная карточка с setup
            mainCard
            
            // Карточка с punchline
            if isExpanded {
                punchlineCard
                    .offset(punchlineOffset)
                    .rotationEffect(.degrees(punchlineRotation))
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.offset(x: 300, y: -100)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.8)),
                            removal: AnyTransition.offset(x: 300, y: -100)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.8))
                        )
                    )
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "\(joke.setup)\n\n\(joke.punchline)\n\nПоделился шуткой из Punch Jokes"
            ])
        }
        .onAppear {
            loadAuthorData()
            checkFavorite()
        }
    }
    
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorInfoView
            
            Text(joke.setup)
                .font(.headline)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            
            actionButtonsView
        }
        .padding(.vertical, 8)
        .background(cardBackground)
        .overlay(cardBorder)
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded = false
                }
            } else {
                isExpanded = true
                punchlineOffset = .zero
                punchlineRotation = 0
            }
        }
    }
    
    private var punchlineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(joke.punchline)
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(
                    gradient: Gradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
    
    private var authorInfoView: some View {
        HStack(spacing: 8) {
            authorImageView
            authorNameView
            Spacer()
            dateView
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    
    private var authorImageView: some View {
        Group {
            if let image = authorImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var authorNameView: some View {
        Text(authorUser?.username ?? joke.author)
            .font(.callout)
            .foregroundColor(.gray)
    }
    
    private var dateView: some View {
        Group {
            if let date = joke.createdAt {
                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            favoriteButton
            Spacer()
            shareButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundColor(isFavorite ? .red : .gray)
                .font(.system(size: 20))
        }
    }
    
    private var shareButton: some View {
        Button(action: { showShareSheet = true }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.gray)
                .font(.system(size: 20))
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ), lineWidth: 1)
    }
    
    private func loadAuthorData() {
        Task {
            if let userData = try? await userService.db.collection("users")
                .whereField("email", isEqualTo: joke.author)
                .getDocuments() {
                if let userDoc = userData.documents.first,
                   let user = try? userDoc.data(as: User.self) {
                    await MainActor.run {
                        self.authorUser = user
                        loadAuthorImage(for: user)
                    }
                }
            }
        }
    }
    
    private func loadAuthorImage(for user: User) {
        Task {
            let storageRef = Storage.storage().reference()
            let imageRef = storageRef.child("users/\(user.id)/profile.jpg")
            
            do {
                let imageData = try await imageRef.data(maxSize: 1 * 1024 * 1024)
                if let image = UIImage(data: imageData) {
                    await MainActor.run {
                        self.authorImage = image
                    }
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func checkFavorite() {
        isFavorite = jokeService.favoriteJokes.contains(joke.id ?? "")
    }
    
    private func toggleFavorite() {
        if let id = joke.id {
            if let index = jokeService.favoriteJokes.firstIndex(where: { $0 == id }) {
                jokeService.favoriteJokes.remove(at: index)
                isFavorite = false
            } else {
                jokeService.favoriteJokes.append(id)
                isFavorite = true
            }
            
            // Синхронизируем с сервером и кешем
            Task {
                if var user = userService.currentUser {
                    // Обновляем данные пользователя
                    user.favouriteJokesIDs = jokeService.favoriteJokes
                    
                    // Сохраняем в JokeService (который сохранит в кеш)
                    jokeService.syncFavorites(with: jokeService.favoriteJokes)
                    
                    // Отправляем на сервер
                    do {
                        try await userService.saveUserToFirestore(user)
                        // Сохраняем обновленного пользователя в кеш
                        userService.saveUserToCache(user)
                    } catch {
                        print("Error saving favorites: \(error)")
                    }
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct JokeCard_Previews: PreviewProvider {
    static var previews: some View {
        let mockJoke = Joke(
            id: "1",
            setup: "Why don't scientists trust atoms?",
            punchline: "Because they make up everything!",
            status: "approved",
            author: "test@test.com"
        )
        
        JokeCard(joke: mockJoke)
            .environmentObject(UserService())
            .environmentObject(JokeService())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
