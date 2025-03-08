import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore

struct JokeCard: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var localFavorites: LocalFavoritesService
    @EnvironmentObject var reactionsService: UserReactionsService
    
    let joke: Joke
    @Binding var expandedJokeId: String?
    
    @State private var isSavingFavorite = false
    @State private var isUpdatingReaction = false
    @State var addPunchline = false
    
    private var isExpanded: Bool {
        expandedJokeId == joke.id
    }
    
    private var authorUsername: String {
        if userService.isLoading {
            return NSLocalizedString("loading", comment: "Loading")
        }
        return userService.userNameCache[joke.authorId] ?? NSLocalizedString("user", comment: "User")
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
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 4)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onTapGesture {
                    hapticFeedback()
                    withAnimation {
                        if isExpanded {
                            expandedJokeId = nil
                        } else {
                            expandedJokeId = joke.id
                        }
                    }
                }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .onAppear {
            Task {
                try? await jokeService.incrementJokeViews(joke.id)
            }
        }
        .sheet(isPresented: $addPunchline) {
            AddJokeSheet(titleTwo: NSLocalizedString("punchline", comment: "Punchline"), joke: joke)
        }
    }
    
    private var mainCard: some View {
        HStack {
            VStack(alignment: .leading) {
                jokeContent
                HStack {
                    authorImage
                    authorAndDate
                }
                if isExpanded {
                    expandedCard
                }
            }
            Spacer()
        }
        .padding()
        .overlay(content: {
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    heartIcon
                    Spacer()
                    shareButton
                }
            }
            .padding()
        })
    }
    
    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(joke.punchlines.sorted(by: { $0.likes > $1.likes })) { punchline in
                PunchlineView(punchline: punchline, jokeId: joke.id)
            }
            
            HStack {
                Spacer()
                GradientButton(name: NSLocalizedString("add_punchline", comment: "Add Punchline"), width: 200.0) {
                    addPunchline = true
                }
                Spacer()
            }
            .padding(0)
        }
        .padding(.top, 8)
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
        .frame(width: 20, height: 20)
        .clipShape(Circle())
    }
    
    var jokeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(joke.setup)
                .font(.body)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .lineSpacing(4)
                .padding(.trailing, 25)
            
            HStack(spacing: 16) {
                Label("\(joke.views)", systemImage: "eye")
                    .foregroundColor(.gray)
                
                Button(action: {
                    guard !isUpdatingReaction else { return }
                    toggleReaction(isLike: true)
                }) {
                    Label("\(joke.likes)", systemImage: reactionsService.getCurrentJokeReaction(for: joke.id) == "like" ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(reactionsService.getCurrentJokeReaction(for: joke.id) == "like" ? .blue : .gray)
                        .opacity(isUpdatingReaction ? 0.5 : 1.0)
                }
                
                Button(action: {
                    guard !isUpdatingReaction else { return }
                    toggleReaction(isLike: false)
                }) {
                    Label("\(joke.dislikes)", systemImage: reactionsService.getCurrentJokeReaction(for: joke.id) == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(reactionsService.getCurrentJokeReaction(for: joke.id) == "dislike" ? .red : .gray)
                        .opacity(isUpdatingReaction ? 0.5 : 1.0)
                }
            }
            .font(.caption)
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
    
    private func toggleFavorite() {
        guard !isSavingFavorite else { return }
        isSavingFavorite = true
        
        Task {
            do {
                if let currentUser = userService.currentUser {
                    var favorites = currentUser.favouriteJokesIDs ?? []
                    if favorites.contains(joke.id) {
                        favorites.removeAll { $0 == joke.id }
                    } else {
                        favorites.append(joke.id)
                    }
                    currentUser.favouriteJokesIDs = favorites
                    try await userService.saveUserToFirestore()
                } else {
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
    
    private func toggleReaction(isLike: Bool) {
        guard let currentUser = userService.currentUser else {
            return
        }
        
        Task {
            isUpdatingReaction = true
            defer { isUpdatingReaction = false }
            
            do {
                let result = try await reactionsService.toggleJokeReaction(userId: currentUser.id, jokeId: joke.id, isLike: isLike)
                try await jokeService.toggleJokeReaction(joke.id, isLike: result.isLike, shouldAdd: result.add)
            } catch {
                print("Error toggling reaction: \(error)")
            }
        }
    }
    
    private func shareJoke() {
        let textToShare = """
        \(joke.setup)
        
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
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var reactionsService: UserReactionsService
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    private var currentReaction: String? {
        reactionsService.getCurrentPunchlineReaction(for: punchline.id)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(punchline.text)
                .font(.headline)
                .foregroundColor(.purple)
                .fontWeight(.medium)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    guard !isUpdating else { return }
                    toggleReaction(isLike: true)
                }) {
                    Label("\(punchline.likes)", systemImage: currentReaction == "like" ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(currentReaction == "like" ? .blue : .gray)
                        .opacity(isUpdating ? 0.5 : 1.0)
                }
                
                Button(action: {
                    guard !isUpdating else { return }
                    toggleReaction(isLike: false)
                }) {
                    Label("\(punchline.dislikes)", systemImage: currentReaction == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(currentReaction == "dislike" ? .red : .gray)
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
    }
    
    private func toggleReaction(isLike: Bool) {
        guard let currentUser = userService.currentUser else {
            errorMessage = NSLocalizedString("login_to_react", comment: "Login to react")
            return
        }
        
        isUpdating = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await reactionsService.togglePunchlineReaction(userId: currentUser.id, punchlineId: punchline.id, isLike: isLike)
                try await jokeService.togglePunchlineReaction(jokeId, punchline.id, isLike: result.isLike, shouldAdd: result.add)
            } catch {
                errorMessage = NSLocalizedString("reaction_update_failed", comment: "Failed to update reaction")
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
    JokeCard(
        joke: Joke(
            id: "123",
            setup: "Setup Setup Setup Setup S S S S S S S S S S S S S S ?",
            punchlines: [Punchline(id: "123", text: "Punch punch punch", status: "approved", authorId: "123123123")],
            status: "approved",
            authorId: "123123123",
            createdAt: Date()
        ),
        expandedJokeId: .constant(nil)
    )
    .environmentObject(AppService())
    .environmentObject(JokeService())
    .environmentObject(UserService())
    .environmentObject(LocalFavoritesService())
    .environmentObject(UserReactionsService())
    .preferredColorScheme(.dark)
}
