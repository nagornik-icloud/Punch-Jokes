import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore

struct JokeCard: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    
    let joke: Joke
    @Binding var expandedJokeId: String?
    
    @StateObject private var viewModel = JokeCardViewModel()
    
    @State var hasReaction: String?
    
    private var isExpanded: Bool {
        expandedJokeId == joke.id
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
                        expandedJokeId = isExpanded ? nil : joke.id
                    }
                }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .onAppear {
            hasReaction = userService.reactionsService
                .getCurrentJokeReaction(for: joke.id)
            Task {
                try? await jokeService.incrementJokeViews(joke.id)
            }
        }
        .sheet(isPresented: $viewModel.addPunchline) {
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
                    viewModel.addPunchline = true
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
                        .frame(width: 40, height: 40)
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
                    Task {
                    
                        if hasReaction == "dislike" {
                            hasReaction = nil
                            try? await userService.reactionsService
                                .toggleReaction(
                                    userId: userService.currentUser?.id ?? "",
                                    id: joke.id,
                                    isLike: false,
                                    type: "joke"
                                )
                            try? await jokeService
                                .toggleJokeReaction(
                                    jokeId: joke.id,
                                    isLike: false,
                                    shouldAdd: false
                                )
                        }
                        
                        if hasReaction == "like" {
                            hasReaction = nil
                            try? await jokeService.toggleJokeReaction(jokeId: joke.id, isLike: true, shouldAdd: false)
                            try? await userService.reactionsService
                                .toggleReaction(
                                    userId: userService.currentUser?.id ?? "",
                                    id: joke.id,
                                    isLike: true,
                                    type: "joke"
                                )
                        } else if hasReaction == nil {
                            hasReaction = "like"
                            try? await jokeService.toggleJokeReaction(jokeId: joke.id, isLike: true, shouldAdd: true)
                            try? await userService.reactionsService
                                .toggleReaction(
                                    userId: userService.currentUser?.id ?? "",
                                    id: joke.id,
                                    isLike: true,
                                    type: "joke"
                                )
                        }
                        
                    }
                }) {
                    Label(
                        "\(joke.likes)", systemImage: hasReaction == "like" ? "hand.thumbsup.fill" : "hand.thumbsup"
                    )
                        .foregroundColor(hasReaction == "like" ? .blue : .gray)
                        .opacity(viewModel.isUpdatingReaction ? 0.5 : 1.0)
                }
                
                Button(action: {
                    Task {
                        
                        if hasReaction == "like" {
                            hasReaction = nil
                            try await userService.reactionsService
                                .toggleReaction(
                                    userId: userService.currentUser?.id ?? "",
                                    id: joke.id,
                                    isLike: true,
                                    type: "joke"
                                )
                            try await jokeService.toggleJokeReaction(jokeId: joke.id, isLike: true, shouldAdd: false)
                        }
                        
                        if hasReaction == "dislike" {
                            hasReaction = nil
                            try await jokeService.toggleJokeReaction(jokeId: joke.id, isLike: false, shouldAdd: false)
                            try await userService.reactionsService
                                .toggleReaction(
                                    userId: userService.currentUser?.id ?? "",
                                    id: joke.id,
                                    isLike: false,
                                    type: "joke"
                                )
                        } else if hasReaction == nil {
                            hasReaction = "dislike"
                            try await jokeService.toggleJokeReaction(jokeId: joke.id, isLike: false, shouldAdd: true)
                            try await userService.reactionsService
                                .toggleReaction(
                                    userId: userService.currentUser?.id ?? "",
                                    id: joke.id,
                                    isLike: false,
                                    type: "joke"
                                )
                        }
                        
                    }
                }) {
                    Label(
                        "\(joke.dislikes)", systemImage: hasReaction == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown"
                    )
                        .foregroundColor(hasReaction == "dislike" ? .red : .gray)
                        .opacity(viewModel.isUpdatingReaction ? 0.5 : 1.0)
                }
            }
            .font(.caption)
        }
    }
    
    var heartIcon: some View {
        Button {
            Task {
                await viewModel
                    .toggleFavorite(
                        joke: joke,
                        userService: userService,
                        localFavorites: userService
                            .localFavoritesService)
            }
        } label: {
            Image(systemName: viewModel.isFavorite(joke: joke, userService: userService, localFavorites: userService.localFavoritesService) ? "heart.fill" : "heart")
                .foregroundColor(viewModel.isFavorite(joke: joke, userService: userService, localFavorites: userService.localFavoritesService) ? .red : .gray)
                .opacity(viewModel.isSavingFavorite ? 0.5 : 1.0)
        }
        .disabled(viewModel.isSavingFavorite)
    }
    
    var authorAndDate: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.authorUsername(joke: joke, userService: userService))
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(joke.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.8))
        }
    }
    
    var shareButton: some View {
        Button(action: {
            viewModel.shareJoke(joke: joke)
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
    }
}

final class JokeCardViewModel: ObservableObject {
    @Published var isSavingFavorite = false
    @Published var isUpdatingReaction = false
    @Published var addPunchline = false
    
    @MainActor
    func toggleFavorite(joke: Joke, userService: UserService, localFavorites: LocalFavoritesService) async {
        guard !isSavingFavorite else { return }
        isSavingFavorite = true
        
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
    
//    @MainActor
//    func toggleReaction(isLike: Bool, joke: Joke, userService: UserService, reactionsService: UserReactionsService, jokeService: JokeService) async {
//        guard let currentUser = userService.currentUser else {
//            return
//        }
//
//        isUpdatingReaction = true
//        defer { isUpdatingReaction = false }
//
//        do {
//            let result = try await reactionsService.toggleReaction(userId: currentUser.id, id: joke.id, isLike: isLike, type: "joke")
//            try await jokeService.toggleJokeReaction(jokeId: joke.id, isLike: result.isLike, shouldAdd: result.add)
//        } catch {
//            print("Error toggling reaction: \(error)")
//        }
//    }
    
    func shareJoke(joke: Joke) {
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
    
    @MainActor
    func isFavorite(joke: Joke, userService: UserService, localFavorites: LocalFavoritesService) -> Bool {
        if let currentUser = userService.currentUser {
            return currentUser.favouriteJokesIDs?.contains(joke.id) ?? false
        } else {
            return localFavorites.contains(joke.id)
        }
    }
    
    @MainActor
    func authorUsername(joke: Joke, userService: UserService) -> String {
        if userService.isLoading {
            return NSLocalizedString("loading", comment: "Loading")
        }
        return userService.userNameCache[joke.authorId] ?? NSLocalizedString("user", comment: "User")
    }
}

struct PunchlineView: View {
    let punchline: Punchline
    let jokeId: String
    
    var body: some View {
        Text(punchline.text)
            .font(.headline)
            .foregroundColor(.purple)
            .fontWeight(.medium)
    }
}
