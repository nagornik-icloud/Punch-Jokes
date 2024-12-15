//
//  UserService.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 19.12.24..
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import FirebaseStorage

struct User: Identifiable {
    var id: String // UID пользователя
    var email: String
    var username: String?
    var name: String?
    var createdAt: Date
    var favouriteJokesIDs: [String]?
}

class UserService: ObservableObject {
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    @Published var currentUser: User?
    @Published var userImage: UIImage?
    @Published var isFirstTime = true {
        didSet {
//            UserDefaults.standard.set(!oldValue, forKey: "isFirstTimeKey")
//            print(oldValue)
        }
    }
    
    init() {
//        let ifFirstTime = UserDefaults.standard.bool(forKey: "isFirstTimeKey")
//        self.isFirstTime = ifFirstTime
        fetchCurrentUser()
        userImage = loadImageFromCache()
       }
    
    
    func registerUser(email: String, password: String, username: String?, completion: @escaping (Result<User, Error>) -> Void) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User creation failed."])))
                return
            }
            
            // Создание нового пользователя
            let newUser = User(id: user.uid, email: email, username: username, createdAt: Date(), favouriteJokesIDs: [])
            self?.currentUser = newUser
            
//            self?.syncroniseJokeIDs(user: newUser)
            
            // Сохраняем данные в Firestore
            self?.saveUserToFirestore(newUser) { saveResult in
                completion(saveResult.map { newUser })
            }
        }
    }
    
    func loginUser(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let uid = result?.user.uid else {
                completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID."])))
                return
            }
            
            // Загружаем пользователя из Firestore
            self?.loadUser(uid: uid) { result in
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    completion(.success(user))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
//    func syncroniseJokeIDs(user: User) {
//        // Теперь не нужно проверять, проинициализирован ли jokeService
//        
//        if currentUser == nil {
//            print("нема пользователя")
//        } else {
//            print("применяем синхронизацию")
//            if user.favouriteJokesIDs?.count ?? 0 > appService.jokeService.favoriteJokes.count {
//                print("на сервере больше - \(user.favouriteJokesIDs?.count ?? 0)")
//                appService.jokeService.favoriteJokes = user.favouriteJokesIDs ?? []
//                print("заполнили локальные. Сейчас всего - \(appService.jokeService.favoriteJokes.count)")
//            } else {
//                print("на устройстве больше - \(appService.jokeService.favoriteJokes.count)")
//                self.currentUser!.favouriteJokesIDs = appService.jokeService.favoriteJokes
//                print("заполнили нашего юзера. Сейчас всего - \(self.currentUser!.favouriteJokesIDs?.count ?? 0)")
//                self.saveUserToFirestore(user) { _ in }
//                print("сохранили в базу")
//            }
//        }
//        
//        
//    }
    
    
    func fetchCurrentUser() {
        guard let uid = auth.currentUser?.uid else {
            currentUser = nil
            print("No authenticated user found.")
            return
        }
        loadUser(uid: uid) { result in
            switch result {
            case .success(let user):
                self.currentUser = user
                print("Current user loaded: \(user.email)")
            case .failure(let error):
                print("Failed to fetch current user: \(error.localizedDescription)")
                self.currentUser = nil
            }
        }
    }
    
    private func loadUser(uid: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                completion(.failure(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User data not found."])))
                return
            }
            
            self.parseUser(from: data, uid: uid, completion: completion)
        }
    }
    
    private func parseUser(from data: [String: Any], uid: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let email = data["email"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data."])))
            return
        }
        
        let username = data["username"] as? String
        let name = data["name"] as? String
        let favouriteJokesIDs = data["favouriteJokesIDs"] as? [String] ?? ["нема шуток"]  // Обработка отсутствующего поля
        let createdAt = createdAtTimestamp.dateValue()
        
        print("favouriteJokesIDs: \(favouriteJokesIDs)")  // Для отладки
        
        let user = User(id: uid, email: email, username: username, name: name, createdAt: createdAt, favouriteJokesIDs: favouriteJokesIDs)
        let imagePath = "user_photos/\(currentUser?.id ?? "random").jpg"
        let ref = storage.reference().child(imagePath)
        
        ref.getData(maxSize: Int64(2 * 1024 * 1024)) { data, error in
            if let error = error {
                print("Error fetching image: \(error.localizedDescription)")
            } else if let data = data, let image = UIImage(data: data) {
                print("Loaded image from Firebase")
                self.userImage = image
                self.saveImageToCache(image: image) // Сохраняем изображение локально
            }
        }
        completion(.success(user))
    }
    
    func saveUserToFirestore(_ user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "username": user.username ?? "",
            "name": user.name ?? "",
            "createdAt": Timestamp(date: user.createdAt),
            "favouriteJokesIDs": user.favouriteJokesIDs ?? []
        ]
        
        db.collection("users").document(user.id).setData(userData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func logoutUser(completion: @escaping (Bool) -> Void) {
        do {
            try auth.signOut()
            self.currentUser = nil
            completion(true)
        } catch {
            completion(false)
        }
    }
    
    func loadImageFromCache() -> UIImage? {
        let filePath = getLocalImagePath()
        if FileManager.default.fileExists(atPath: filePath.path) {
            return UIImage(contentsOfFile: filePath.path)
        }
        return nil
    }
    func getLocalImagePath() -> URL {
        return imageCachePath.appendingPathComponent("\(currentUser?.id ?? "default_user").jpg")
    }
    
    let imageCachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let storage = Storage.storage()
    
    func saveImageToCache(image: UIImage) {
        let filePath = getLocalImagePath()
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        do {
            try data.write(to: filePath)
            print("Image saved locally at \(filePath)")
        } catch {
            print("Error saving image locally: \(error.localizedDescription)")
        }
    }
}
