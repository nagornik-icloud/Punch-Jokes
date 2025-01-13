//
//  SendJokeView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 21.12.24..
//

import SwiftUI
import FirebaseFirestore

struct JokeStatusView: View {
    let status: String
    
    var body: some View {
        Text(status == "pending" ? "На модерации" : "Одобрено")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(status == "pending" ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
            )
            .foregroundColor(status == "pending" ? .orange : .green)
    }
}

struct AddJokeSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @State private var setup = ""
    @State private var punchline = ""
    
    let titleOne: String = "Сетап"
    let titleTwo: String
    
    var isPunchline: Bool {
        self.joke != nil
    }
    
    let joke: Joke?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Form {
                    if !isPunchline {
                        Section(header: Text(titleOne)) {
                            TextEditor(text: $setup)
                                .frame(height: 100)
                        }
                    }
                    Section(header: Text(titleTwo)) {
                        TextEditor(text: $punchline)
                            .frame(height: 100)
                    }
                }
                
                Button {
                    Task {
                        if !isPunchline {
                            try? await jokeService.addJoke(
                                user: userService.currentUser,
                                setup: setup,
                                punchline: punchline
                            )
                        } else {
                            try? await jokeService.addPunchline(
                                toJokeId: joke!.id,
                                text: punchline,
                                authorId: userService.currentUser?.id
                            )
                        }
                    }
                } label: {
                    if jokeService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Отправить на модерацию")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    punchline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    jokeService.isLoading ? Color.blue.opacity(0.5) : Color.blue
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal)
                .disabled(
                    setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    punchline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    jokeService.isLoading
                )
            }
            .navigationTitle("Новая шутка")
            .alert("Внимание", isPresented: $jokeService.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(jokeService.alertMessage)
            }
        }
    }
    
//    private func sendJoke() {
//        guard let currentUser = userService.currentUser else {
//            jokeService.alertMessage = "Необходимо войти в аккаунт"
//            jokeService.showAlert = true
//            return
//        }
//        
//        isLoading = true
//        
//        Task {
//            do {
//                try await jokeService.addJoke(
//                        setup: setup,
//                        punchline: punchline,
//                        authorId: currentUser.id
//                    )
//                isLoading = false
//                dismiss()
//            } catch {
//                jokeService.alertMessage = "Ошибка: \(error.localizedDescription)"
//                jokeService.showAlert = true
//            }
//            isLoading = false
//        }
//    }
}

struct SendJokeView: View {
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @State private var showAddJokeSheet = false
    @Environment(\.colorScheme) var colorScheme
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var userJokes: [Joke] {
        guard let currentUser = userService.currentUser else { return [] }
        return jokeService.jokes
            .filter { joke in
                joke.authorId == currentUser.id &&
                (joke.status == "pending" || joke.status == "approved")
            }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if userService.currentUser == nil {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Войдите в аккаунт")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Чтобы добавлять свои шутки, вам нужно войти в аккаунт или зарегистрироваться")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appService.shownScreen = .account
                            }
                        }) {
                            Text("Войти или зарегистрироваться")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                } else {
                    if jokeService.isLoading {
                        ProgressView()
                    } else if userJokes.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("У вас пока нет шуток")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Нажмите + чтобы добавить первую")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(userJokes) { joke in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text(dateFormatter.string(from: joke.createdAt ?? Date()))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            JokeStatusView(status: joke.status)
                                        }
                                        
                                        JokeCard(joke: joke)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                            Color.clear
                                .frame(height: 100)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .navigationTitle("Мои шутки")
            .sheet(isPresented: $showAddJokeSheet) {
                AddJokeSheet(titleTwo: "Панчлайн", joke: nil)
            }
        }
        .overlay(alignment: .topTrailing) {
            if userService.currentUser != nil {
                Button(action: { showAddJokeSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .padding(.top, 52)
                }
                .padding(.trailing, 24)
            }
        }
    }
}

#Preview {
    SendJokeView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
