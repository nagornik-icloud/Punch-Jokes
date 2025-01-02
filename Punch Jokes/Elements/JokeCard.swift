//
//  JokeCard.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI
import FirebaseFirestore

struct JokeCard: View {
    let joke: Joke
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    
    @State private var isFavorite: Bool = false
    @State private var showShareSheet = false
    @State private var isShowingPunchline = false
    @State private var shakeEffect: CGFloat = 0
    
    private var authorUsername: String {
        userService.allUsers.first(where: { $0.id == joke.author })?.username ?? "Пользователь"
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            authorInfoView
            jokeContentView
            actionButtonsView
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: checkFavorite)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
        .rotation3DEffect(.degrees(shakeEffect * 5), axis: (x: 0, y: 1, z: 0))
        .scaleEffect(1 + shakeEffect * 0.05)
    }
    
    private var authorInfoView: some View {
        HStack {
            authorImageView
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authorUsername)
                    .font(.headline)
                if let date = joke.createdAt {
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var authorImageView: some View {
        Group {
            if let image = jokeService.userPhotos[joke.author] {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    private var jokeContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(joke.setup)
                .font(.body)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
            
            if isShowingPunchline {
                Text(joke.punchline)
                    .font(.body.bold())
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.2).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isShowingPunchline)
        .onTapGesture {
            handleTap()
        }
    }
    
    private var actionButtonsView: some View {
        HStack {
            
            Button {
                Task {
                    await toggleFavorite()
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .gray)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
            
//            Button(action: try! toggleFavorite) {
//                Image(systemName: isFavorite ? "heart.fill" : "heart")
//                    .foregroundColor(isFavorite ? .red : .gray)
//                    .font(.title2)
//            }
//            .buttonStyle(BorderlessButtonStyle())
            
            Spacer()
            
            Button(action: { showShareSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.top, 8)
    }
    
    private var shareText: String {
        "\(joke.setup)\n\n\(joke.punchline)\n\nПоделился шуткой из Punch Jokes"
    }
    
    private func handleTap() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            shakeEffect = 1
        }
//        withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.1)) {
//
//        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                shakeEffect = 0
                isShowingPunchline.toggle()
            }
        }
    }
    
    private func checkFavorite() {
        isFavorite = jokeService.favoriteJokes.contains(joke.id ?? "")
    }
    
    private func toggleFavorite() async {
        jokeService.toggleFavorite(joke.id ?? "")
        syncroniseFavouriteJokes()
        await updateUserFavouteJokes()
        isFavorite.toggle()
    }
    
    private func syncroniseFavouriteJokes() {
        guard let user = userService.currentUser else { return }
        let local = jokeService.favoriteJokes
        let server = user.favouriteJokesIDs
        
        // Синхронизируем локальные избранные с серверными
        if local.count <= server!.count {
            jokeService.favoriteJokes = server!
        } else {
            userService.currentUser!.favouriteJokesIDs = local
        }
    }
    
    private func updateUserFavouteJokes() async {
        if let user = userService.currentUser {
            print("try to upload jokes")
            try? await userService.saveUserToFirestore(user)
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
