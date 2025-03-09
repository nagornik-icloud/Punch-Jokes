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
        
        FirebaseApp.configure()
        LocalStorage.setupDirectories()

    }
    
    var body: some Scene {
        WindowGroup {
            TabBarView()
                .environmentObject(appService)
                .environmentObject(userService)
                .environmentObject(jokeService)
                .preferredColorScheme(.dark)
        }
    }
    
}

//#Preview {
//    TabBarView()
//        .environmentObject(AppService())
//        .environmentObject(JokeService())
//        .environmentObject(UserService())
//        .preferredColorScheme(.dark)
//}

func hapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}
