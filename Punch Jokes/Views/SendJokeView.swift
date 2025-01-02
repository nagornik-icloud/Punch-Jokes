//
//  SendJokeView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 21.12.24..
//

import SwiftUI
import FirebaseFirestore

struct SendJokeView: View {
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    
    @State private var setup = ""
    @State private var punchline = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Новая шутка")) {
                    TextField("Начало шутки", text: $setup)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Конец шутки", text: $punchline)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button(action: sendJoke) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Отправить")
                        }
                    }
                    .disabled(setup.isEmpty || punchline.isEmpty || isLoading)
                }
            }
            .navigationTitle("Добавить шутку")
            .alert("Внимание", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func sendJoke() {
        guard let currentUser = userService.currentUser else {
            alertMessage = "Необходимо войти в аккаунт"
            showAlert = true
            return
        }
        
        isLoading = true
        
//        Task {
//            do {
//                try await jokeService.addJoke(setup, punchline, author: currentUser.id)
//                setup = ""
//                punchline = ""
//                alertMessage = "Шутка успешно добавлена!"
//            } catch {
//                alertMessage = "Ошибка: \(error.localizedDescription)"
//            }
//            
//            isLoading = false
//            showAlert = true
//        }
    }
}

#Preview {
    SendJokeView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
