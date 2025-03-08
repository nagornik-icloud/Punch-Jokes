import SwiftUI

struct AllJokesView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @Environment(\.colorScheme) var colorScheme
    
    @State var showError = false
    @State var errorMessage = ""
    @State private var expandedJokeId: String? = nil
    
    var sortedJokes: [Joke] {
        jokeService.jokes
            .filter { $0.status == "approved" }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if jokeService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(LocalizedStringKey("loading_jokes"))
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else if sortedJokes.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("no_jokes"),
                        systemImage: "text.bubble",
                        description: Text(LocalizedStringKey("no_approved_jokes"))
                    )
                } else {
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) { // Use LazyVStack
                                ForEach(sortedJokes) { joke in
                                    JokeCard(joke: joke, expandedJokeId: $expandedJokeId)
                                        .padding(.horizontal)
                                        .id(joke.id) // Ensure ID is non-optional & unique
                                        .highPriorityGesture(
                                            TapGesture()
                                                .onEnded { _ in
                                                    print("Tapped joke ID: \(joke.id)")
                                                    if expandedJokeId == joke.id {
                                                        expandedJokeId = nil
                                                    } else {
                                                        expandedJokeId = joke.id
                                                        
                                                        DispatchQueue.main.async { // Ensures the view is updated before scrolling
                                                            print("Scrolling to joke ID: \(joke.id)")
                                                            withAnimation(.spring(response: 0.8, dampingFraction: 0.5, blendDuration: 0.5)) {
                                                                proxy
                                                                    .scrollTo(
                                                                        joke.id,
                                                                        anchor: .top
                                                                    )
                                                            }
                                                        }
                                                        
                                                        
                                                    }
                                                }
                                        )
//                                        .onTapGesture {
//                                            print("Tapped joke ID: \(joke.id)")
//                                            if expandedJokeId == joke.id {
//                                                expandedJokeId = nil
//                                            } else {
//                                                expandedJokeId = joke.id
//                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Ensures the view is updated before scrolling
//                                                    print("Scrolling to joke ID: \(joke.id)")
//                                                    proxy
//                                                        .scrollTo(
//                                                            joke.id,
//                                                            anchor: .center
//                                                        )
//                                                }
//                                            }
//                                        }
                                }

                                if jokeService.isLoadingMore {
                                    ProgressView()
                                        .padding()
                                }
                            }
                            .padding(.vertical)
                        }
//                        .appBackground()
                        .scrollIndicators(.hidden)
                    }

                    
                }
            }
//            .background(Color.clear)
            .navigationTitle(LocalizedStringKey("all_jokes"))
            .refreshable {
                Task {
                    await refreshJokes()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    func refreshJokes() async {
        do {
            print("Refreshing jokes...")
            await jokeService.loadData()
            await userService.loadInitialData()
            print("Jokes refreshed, count: \(jokeService.jokes.count)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
