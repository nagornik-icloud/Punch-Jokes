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
    
    
    init() {
        // Инициализация Firebase
        FirebaseApp.configure()

        
        
    }
    
    var body: some Scene {
        WindowGroup {
            TabBarView()
                .environmentObject(appService)
                .environmentObject(userService)
                .environmentObject(jokeService)
            
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

