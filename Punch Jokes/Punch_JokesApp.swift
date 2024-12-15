//
//  Punch_JokesApp.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 15.12.24..
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseCore

@main
struct YourApp: App {
    
    init() {
        
        // Инициализация Firebase
        FirebaseApp.configure()
        
    }

    var body: some Scene {
        WindowGroup {
            TabBarView()  // Твой основной интерфейс
        }
    }
}
