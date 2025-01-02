//
//  Punch_JokesApp.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import GoogleSignIn

@main
struct YourApp: App {
    
    @StateObject var appService = AppService()
    @StateObject var userService = UserService()
    @StateObject var jokeService = JokeService()
    @State private var isLoading = false
    
    init() {
        // Инициализация Firebase
        FirebaseApp.configure()
        LocalStorage.setupDirectories()
        
        
    }
    
    var body: some Scene {
        WindowGroup {
            TabBarView()
                .environmentObject(appService)
                .environmentObject(userService)
                .environmentObject(jokeService)
//                .task {
//                    print("📱 App: Loading initial data...")
//                    await userService.loadInitialData()
//                    await jokeService.loadInitialData()
//                    isLoading = false
//                    print("📱 App: Initial load complete")
//                }
            
        }
    }
    
    
}

let db = Firestore.firestore()

#Preview {
    TabBarView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
