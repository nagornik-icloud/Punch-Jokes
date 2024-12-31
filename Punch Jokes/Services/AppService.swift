//
//  AppService.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 20.12.24..
//

import Foundation
import SwiftUI

class AppService: ObservableObject {
    
    enum AppScreens {
        case onboarding
        case allJokes
        case favorites
        case myJokes
        case settings
        case account
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
