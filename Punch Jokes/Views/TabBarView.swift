//
//  tabBarView.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI
import UIKit
import Combine

// MARK: - Gesture Handler
class ClearCacheGestureHandler: NSObject {
    static let shared = ClearCacheGestureHandler()
    
    @objc func handleGesture(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            NotificationCenter.default.post(name: NSNotification.Name("ShowClearCacheAlert"), object: nil)
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct TabBarView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    let screens: [AppService.AppScreens] = [.allJokes, .favorites, .myJokes, .account]

    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible = false
    @State private var showingClearCacheAlert = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(colorScheme == .dark ? .black : .white),
                Color.purple.opacity(0.2)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            // Фоновый градиент
            backgroundGradient
                .ignoresSafeArea()
            
            if userService.isLoading || jokeService.isLoading {
                LoadingView()
            } else {
                mainContent
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                if isKeyboardVisible {
                                    UIApplication.shared.endEditing()
                                }
                            }
                    )
            }
        }
        .onAppear {
            Task {
                print("TabBarView appeared, fetching jokes...")
                setupKeyboardObservers()
                setupClearCacheGesture()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .alert("Очистить кеш?", isPresented: $showingClearCacheAlert) {
            Button("Очистить", role: .destructive) {
                clearCache()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие очистит весь кеш приложения. Потребуется перезагрузка.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowClearCacheAlert"))) { _ in
            showingClearCacheAlert = true
        }
        
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Основной контент
            ZStack {
                switch appService.shownScreen {
                case .allJokes:
                    AllJokesView()
                case .favorites:
                    FavoritesView()
                case .myJokes:
                    SendJokeView()
                case .account:
                    AccountView()
                case .onboarding:
                    EmptyView()
                case .settings:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom TabBar
            if appService.showTabBar && !isKeyboardVisible {
                customTabBar
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: isKeyboardVisible)
                    .animation(.spring(), value: appService.showTabBar)
            }
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(screens, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appService.shownScreen = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 24, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(appService.shownScreen == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThickMaterial.opacity(0.95))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 2, y: 6)
        .padding(8)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            withAnimation {
                self.isKeyboardVisible = true
                self.appService.showTabBar = false
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            withAnimation {
                self.isKeyboardVisible = false
                self.appService.showTabBar = true
            }
        }
    }
    
    private func setupClearCacheGesture() {
        let gesture = UILongPressGestureRecognizer(target: ClearCacheGestureHandler.shared, action: #selector(ClearCacheGestureHandler.handleGesture(_:)))
        gesture.minimumPressDuration = 3
        gesture.delaysTouchesBegan = true
        gesture.cancelsTouchesInView = false
        UIApplication.shared.keyWindow?.addGestureRecognizer(gesture)
    }
    
    private func clearCache() {
        LocalStorage.clearAllCache()
        // Перезапускаем приложение
        exit(0)
    }
}

#Preview {
    TabBarView()
        .environmentObject(UserService())
        .environmentObject(JokeService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
