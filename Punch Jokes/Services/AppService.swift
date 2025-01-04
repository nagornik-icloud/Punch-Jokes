//
//  AppService.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 20.12.24..
//

import Foundation
import SwiftUI

class AppService: ObservableObject {
    
    enum AppScreens: String, CaseIterable {
        case onboarding
        case allJokes = "house"
        case favorites = "heart"
        case myJokes = "plus"
        case settings
        case account = "person"
        
        var title: String {
            switch self {
            case .allJokes:
                return "Все шутки"
            case .favorites:
                return "Избранное"
            case .myJokes:
                return "Добавить"
            case .account:
                return "Профиль"
            case .onboarding:
                return ""
            case .settings:
                return ""
            }
        }
        
    }
    
    @Published var shownScreen: AppScreens = .allJokes {
        didSet {
            self.lastScreen = oldValue
        }
    }
    @Published var lastScreen: AppScreens = .allJokes
    @Published var showTabBar = true
    @Published var isInitializing = true
    
    
    
    func closeAccScreen() {
        shownScreen = lastScreen
        showTabBar = true
    }
}
