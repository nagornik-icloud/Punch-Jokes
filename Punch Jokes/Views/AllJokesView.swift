import SwiftUI

struct AllJokesView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @Environment(\.colorScheme) var colorScheme
    
    @State var showError = false
    @State var errorMessage = ""
//    @State private var expandedJokeId: String? = nil
    
    
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
                            LazyVStack(spacing: 16) {
                                ForEach(sortedJokes) { joke in
                                    JokeCard(joke: joke, expandedJokeId: $appService.expandedJokeId)
                                        .padding(.horizontal)
                                        .id(joke.id)
                                        
                                }

                                if jokeService.isLoadingMore {
                                    ProgressView()
                                        .padding()
                                }
                            }
                            .padding(.vertical)
                        }
                        .appBackground() // Uncommented to apply background styling
                        .scrollIndicators(.hidden)
                        
                        .onAppear {
                            appService.proxy = proxy
                        }
                        .onChange(of: appService.expandedJokeId) { _, _ in
                            DispatchQueue.main.async {
                                print("Scrolling to joke ID: \(appService.expandedJokeId ?? "")")
                                withAnimation(.spring(response: 1, dampingFraction: 0.5, blendDuration: 0.5)) {
                                    proxy.scrollTo(appService.expandedJokeId, anchor: .top)
                                }
                            }
                            appService.proxy = proxy
                        }
                        
                    }
                    
                }
            }
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
    
//    private func handleTapGesture(_ joke: Joke, proxy: ScrollViewProxy) {
//        print("Tapped joke ID: \(joke.id)")
//        if appService.expandedJokeId == joke.id {
//            appService.expandedJokeId = nil
//        } else {
//            appService.expandedJokeId = joke.id
//            DispatchQueue.main.async {
//                print("Scrolling to joke ID: \(joke.id)")
//                withAnimation(.spring(response: 1, dampingFraction: 0.5, blendDuration: 0.5)) {
//                    proxy.scrollTo(joke.id, anchor: .top)
//                }
//            }
//        }
//    }
    
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
