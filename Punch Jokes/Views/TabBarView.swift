//
//  tabBarView.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI
import FirebaseStorage
import UIKit
import Combine

struct TabBarView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @State private var selectedTab: Tab = .home
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible = false
    
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
            
            if !userService.loaded {
                LoadingView()
            } else {
                mainContent
            }
        }
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Content
            ZStack {
                switch selectedTab {
                case .home:
                    AllJokesView()
                case .favorites:
                    FavoritesView()
                case .add:
                    SendJokeView()
                case .profile:
                    AccountView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom TabBar
            if !isKeyboardVisible {
                customTabBar
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: isKeyboardVisible)
            }
        }
        .overlay(
            FavoriteSyncView()
        )
        .onTapGesture {
            if isKeyboardVisible {
                UIApplication.shared.endEditing()
            }
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 24, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 2, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            withAnimation {
                self.isKeyboardVisible = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            withAnimation {
                self.isKeyboardVisible = false
            }
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
