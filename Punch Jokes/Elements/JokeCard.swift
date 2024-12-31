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
    
    @State private var authorImage: UIImage?
    @State private var authorName: String = ""
    @State private var isFavorite: Bool = false
    @State private var showShareSheet = false
    @State private var isShowingPunchline = false
    @State private var shakeEffect: CGFloat = 0
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: handleTap) {
            VStack(alignment: .leading, spacing: 16) {
                authorInfoView
                jokeContentView
                actionButtonsView
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: setupCard)
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
                Text(authorName)
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
            if let image = authorImage {
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
    }
    
    private var actionButtonsView: some View {
        HStack {
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .gray)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
            
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
    
    private func setupCard() {
        checkFavorite()
        loadAuthorData()
    }
    
    private func handleTap() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            shakeEffect = 1
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.1)) {
            shakeEffect = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isShowingPunchline.toggle()
            }
        }
    }
    
    private func loadAuthorData() {
        let authorId = joke.author
        
        // Загружаем имя автора
        Task {
            do {
                // Проверяем кэш
                if let cachedName = userService.userNameCache[authorId] {
                    self.authorName = cachedName
                    return
                }
                
                // Загружаем из Firebase
                let userDoc = try await userService.db.collection("users")
                    .document(authorId)
                    .getDocument()
                
                if let userData = userDoc.data(),
                   let username = userData["username"] as? String {
                    self.authorName = username
                    userService.userNameCache[authorId] = username
                } else {
                    self.authorName = "Пользователь"
                    userService.userNameCache[authorId] = "Пользователь"
                }
            } catch {
                print("Error loading author name: \(error)")
                self.authorName = "Пользователь"
                userService.userNameCache[authorId] = "Пользователь"
            }
        }
        
        // Загружаем аватар
        if let cachedImage = userService.imageCache.object(forKey: "user_photo_\(authorId)" as NSString) {
            self.authorImage = cachedImage
            return
        }
        
        Task {
            do {
                let imageURL = userService.imageCacheDirectory.appendingPathComponent("\(authorId).jpg")
                if let data = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: data) {
                    self.authorImage = image
                    userService.imageCache.setObject(image, forKey: "user_photo_\(authorId)" as NSString)
                    return
                }
                
                let storageRef = userService.storage.reference()
                let imageRef = storageRef.child("user_photos/\(authorId).jpg")
                let data = try await imageRef.data(maxSize: 5 * 1024 * 1024)
                
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.authorImage = image
                    }
                    userService.imageCache.setObject(image, forKey: "user_photo_\(authorId)" as NSString)
                    try? data.write(to: imageURL)
                }
            } catch {
                print("Error loading author image: \(error)")
            }
        }
    }
    
    private func checkFavorite() {
        if let jokeId = joke.id {
            isFavorite = jokeService.favoriteJokes.contains(jokeId)
        }
    }
    
    private func toggleFavorite() {
        guard let jokeId = joke.id else { return }
        
        if isFavorite {
            jokeService.favoriteJokes.removeAll { $0 == jokeId }
        } else {
            jokeService.favoriteJokes.append(jokeId)
        }
        isFavorite.toggle()
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
