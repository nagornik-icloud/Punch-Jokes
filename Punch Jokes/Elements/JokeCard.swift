//
//  JokeCardView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI

struct JokeCard: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    let joke: Joke
    
    var isExpanded: Bool = false
    var onTap: () -> Void
    var isFavorite: Bool {
        if jokeService.favoriteJokes.contains(joke.id!) || userService.currentUser?.favouriteJokesIDs?.contains(joke.id!) ?? false {
            return true
        } else {
            return false
        }
        
    }

    var body: some View {
        ZStack {
            // Задняя сторона (панчлайн)
            ZStack {
                if isExpanded {
                    VStack {
                        Text(joke.punchline)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .rotation3DEffect(
                        .degrees(isExpanded ? 180 : 0),
                        axis: (x: 1, y: 0.0, z: 0)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom))
                    .cornerRadius(16)
                    .shadow(radius: 4)
                    
                } else {
                    // Передняя сторона (затравка)
                    Text(joke.setup)
                        .font(.headline)
                        .multilineTextAlignment(.center)
//                        .foregroundColor(.black)
                        .padding()
                }
                
                VStack {
                    
                    if isExpanded {
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .gray)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                                .rotation3DEffect(
                                    .degrees(isExpanded ? 180 : 0),
                                    axis: (x: 1, y: 0.0, z: 0)
                                )
                        }
//                        .rotation3DEffect(
//                            .degrees(isExpanded ? 180 : 0),
//                            axis: (x: 10, y: 0.0, z: 1.0)
//                        )
                        .padding(8)
                        
                    }
                    
                    if !isExpanded {
                        Spacer()
                    }
                    
                }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Color.gray.opacity(0.1))
            .background(.secondary)
            .cornerRadius(16)
            .shadow(radius: 4)
            .onTapGesture {
                withAnimation(.spring(duration: 0.4, bounce: 0.6) ) {
                    onTap()  // Вызов переданной функции на тап
                }
            }
            
        }
        .offset(x: isExpanded ? -20 : 0)
        .frame(height: 140)
        .shadow(radius: 4)
        .rotation3DEffect(
            .degrees(isExpanded ? 180 : 0),
            axis: (x: 10, y: 0.0, z: 1.0)
        )
        
    }

    private func toggleFavorite() {
        if let index = jokeService.favoriteJokes.firstIndex(where: { $0 == joke.id }) {
            jokeService.favoriteJokes.remove(at: index)
            guard userService.currentUser != nil else { return }
            userService.currentUser!.favouriteJokesIDs?.remove(at: index)
        } else {
            jokeService.favoriteJokes.append(joke.id!)
            guard userService.currentUser != nil else { return }
            userService.currentUser!.favouriteJokesIDs?.append(joke.id!)
        }
        if let userToSave = userService.currentUser {
            userService.saveUserToFirestore(userToSave) { _ in
            }
        }
    }
    
    

}

#Preview {
    TabBarView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
