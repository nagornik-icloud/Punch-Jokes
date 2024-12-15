//
//  SendJokeView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 21.12.24..
//

import SwiftUI

//struct SendJokeView: View {
//    
//    @EnvironmentObject var jokeService: JokeService
//    @EnvironmentObject var userService: UserService
//    @EnvironmentObject var appService: AppService
//    
//    var body: some View {
//        
//        ZStack {
//            if userService.currentUser != nil {
//                loggedIn
//            } else {
////                LoginScreenView()
//
//            }
//        }
//       
//    }
//    
//    private var loggedIn: some View {
//        VStack {
//            Text("add a joke")
//            Text("\(userService.currentUser?.email ?? "no user email, why?")")
//            Text("всего шуток - \(jokeService.allJokes.count)")
//            Text("у юзера любимых - \(userService.currentUser?.favouriteJokesIDs?.count ?? 0)")
////                    Text(userService.currentUser?.favouriteJokesIDs?.joined(separator: ", ") ?? "no fav jokes")
////                    Text("jokesService\(jokeService.favoriteJokes)")
//            Text("локальных любимых - \(jokeService.favoriteJokes.count)")
////                    Text("локальных любимых - \(localJokeService.favoriteJokes.count)")
//            Button {
//                userService.logoutUser { Bool in
//                    print("logout")
//                }
//            } label: {
//                Text("Logout")
//            }
//        }
//    }
//    
//    private var loginView: some View {
//        VStack {
//            Text(userService.currentUser?.email ?? "not logged in, it's OK")
//            Button("Войти") {
//                userService.loginUser(email: "nagorny.anton@gmail.com", password: "65151128") { result in
//                    switch result {
//                    case .success:
//                        print("User logged in: \(userService.currentUser?.email ?? "why noo current user?")")
//                    case .failure(let error):
//                        print("Error logging in: \(error.localizedDescription)")
//                    }
//                }
//            }
//            .padding()
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(8)
//        }
//    }
//    
//    
//    
//}

//
//  MyJokesView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 16.12.24..
//

import SwiftUI
import Foundation

struct SendJokeView: View {


    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var appService: AppService

    private var isUserAuthenticated: Bool {
        userService.currentUser != nil
    }
    @State private var userJokes: [Joke] = []
    @State private var newJoke = Joke(id: UUID().uuidString, setup: "", punchline: "", status: "pending", author: "")
    @State private var isSuccess = false
    @State private var isButtonDisabled = false
    @State private var timer: Int = 5
    @State private var isLoading = true
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var currentUserEmail = ""


//    @State var currentUser = User?.self

    init() {
//        self.email = userService.getCurrentUserEmail()
//        self.us = userService
    }

    var isFormValid: Bool {
        !newJoke.setup.isEmpty && !newJoke.punchline.isEmpty && newJoke.setup.count > 3 && newJoke.punchline.count > 3
    }

    var body: some View {
        Group {
            if isUserAuthenticated {
                jokesContentView

            } else {
                AccountView()
            }
        }
        .onAppear {
//            currentUserEmail = userService.getCurrentUserEmail()
            fetchUserJokes { result in
                switch result {
                    case .success(let jokes):
                    self.userJokes = jokes
                    case .failure(let error):
                        print("Error fetching jokes: \(error.localizedDescription)")
                    }
            }
        }
    }

    private var jokesContentView: some View {
        VStack(spacing: 16) {
            Text("Ваши шутки")
                .font(.headline)
                .padding()

            Text(currentUserEmail)

           if userJokes.isEmpty {
                Text("Вы ещё не отправляли шутки.")
                    .foregroundColor(.gray)
            } else {
                List(userJokes) { joke in
                    VStack(alignment: .leading) {
                        Text(joke.setup)
                            .font(.headline)
                        Text(joke.punchline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("Статус: \(joke.status.capitalized)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("Автор: \(joke.author)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Text("Отправлено: \(formattedDate(joke.id))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }

            Divider()

            TextField("Введите setup", text: $newJoke.setup)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 5)
                .padding([.leading, .trailing])

            TextField("Введите punchline", text: $newJoke.punchline)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 5)
                .padding([.leading, .trailing])

            Button(action: sendJoke) {
                Text("Отправить на премодерацию")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isButtonDisabled ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .opacity(isButtonDisabled ? 0.5 : 1.0)
            }
            .disabled(!isFormValid || isButtonDisabled)
            Button {
                userService.logoutUser { success in
                    userJokes = []
                }
            } label: {
                Text("logout")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isButtonDisabled ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .opacity(isButtonDisabled ? 0.5 : 1.0)
            }


            if isSuccess {
                Text("Шутка успешно отправлена!")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }

            if isButtonDisabled {
                Text("Подождите \(timer) секунд...")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: timer)
            }
        }
        .padding()
        .onChange(of: isButtonDisabled) { _, newValue in
            if newValue {
                startTimer()
            }
        }
    }

//    private var authView: some View {
//        VStack(spacing: 16) {
//            Text("Авторизация")
//                .font(.largeTitle)
//                .padding()
//
//            TextField("Email", text: $email)
//                .keyboardType(.emailAddress)
//                .padding()
//                .background(Color.white)
//                .cornerRadius(8)
//                .shadow(radius: 5)
//                .padding([.leading, .trailing])
//
//            SecureField("Пароль", text: $password)
//                .padding()
//                .background(Color.white)
//                .cornerRadius(8)
//                .shadow(radius: 5)
//                .padding([.leading, .trailing])
//
//            if !errorMessage.isEmpty {
//                Text(errorMessage)
//                    .foregroundColor(.red)
//                    .font(.subheadline)
//            }
//
//            Button {
//                loginUser()
//                print("\(userService.currentUser?.email)")
//                print("\(currentUserEmail)")
//            } label: {
//                Text("Войти")
//                    .fontWeight(.bold)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//            }
//
////            Button(action: loginUser) {
////                Text("Войти")
////                    .fontWeight(.bold)
////                    .padding()
////                    .frame(maxWidth: .infinity)
////                    .background(Color.blue)
////                    .foregroundColor(.white)
////                    .cornerRadius(8)
////            }
//            .padding([.leading, .trailing])
//
//            Button(action: registerUser) {
//                Text("Зарегистрироваться")
//                    .fontWeight(.bold)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.green)
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//            }
//            .padding([.leading, .trailing])
//        }
//        .padding()
//    }
    
    func fetchUserJokes(completion: @escaping (Result<[Joke], Error>) -> Void) {
        guard let currentUser = userService.currentUser else {
            completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No current user."])))
            return
        }
        
        let email = currentUser.email
        let username = currentUser.username ?? ""
        let name = currentUser.name ?? ""
        
        db.collection("jokes")
            .whereField("author", in: [email, username, name]) // Ищем шутки по автору
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No jokes found."])))
                    return
                }
                
                // Преобразуем документы в массив шуток
                let jokes = documents.compactMap { document -> Joke? in
                    do {
                        return try document.data(as: Joke.self) // Используем Codable для десериализации
                    } catch {
                        print("Error parsing joke: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                completion(.success(jokes))
            }
    }


    private func loginUser() {
        userService.loginUser(email: email, password: password) { result in
            switch result {
            case .success(let email):
                newJoke.author = email.email // Устанавливаем текущего пользователя автором шутки
                    self.email = email.email
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func registerUser() {
        userService.registerUser(email: email, password: password, username: nil) { result in
            switch result {
            case .success(let email):
                currentUserEmail = email.email
                newJoke.author = email.email
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendJoke() {
        newJoke.author = currentUserEmail
        jokeService.addJokeForModeration(joke: newJoke) { success in
            isSuccess = success
            if success {
                userJokes.append(newJoke)
                newJoke = Joke(id: UUID().uuidString, setup: "", punchline: "", status: "pending", author: userService.currentUser!.username ?? userService.currentUser!.name ?? userService.currentUser!.email)
                isButtonDisabled = true
            }
        }
    }

    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if timer > 0 {
                timer -= 1
                startTimer()
            } else {
                isButtonDisabled = false
                timer = 5
            }
        }
    }

    private func formattedDate(_ id: String?) -> String {
        guard let id = id else { return "—" }
        return id.prefix(8).description
    }
}


#Preview {
    SendJokeView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
