//
//  SendJokeView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 21.12.24..
//

import SwiftUI
import FirebaseFirestore

struct SendJokeView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    @State private var joke = Joke()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            TextField("Setup", text: $joke.setup)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            TextField("Punchline", text: $joke.punchline)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                sendJoke()
            }) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Send Joke")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .disabled(joke.setup.isEmpty || joke.punchline.isEmpty || isLoading)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func sendJoke() {
        guard let userId = userService.currentUser?.id else {
            alertMessage = "You must be logged in to send jokes"
            showAlert = true
            return
        }
        
        isLoading = true
        joke.author = userId
        joke.status = "pending"
        joke.createdAt = Date()
        
        Task {
            do {
                let jokeRef = try await jokeService.db.collection("jokes").addDocument(from: joke)
                joke.id = jokeRef.documentID
                
                // Добавляем в список всех шуток
                jokeService.allJokes.append(joke)
                jokeService.saveJokesToCache(jokeService.allJokes)
                
                // Очищаем форму
                joke = Joke()
                
                alertMessage = "Joke sent successfully!"
                showAlert = true
            } catch {
                alertMessage = "Error sending joke: \(error.localizedDescription)"
                showAlert = true
            }
            
            isLoading = false
        }
    }
}

#Preview {
    SendJokeView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
