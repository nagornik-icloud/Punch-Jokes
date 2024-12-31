//
//  tabBarView.swift
//  test
//
//  Created by Anton Nagornyi on 15.12.24..
//

import SwiftUI


struct TabBarView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @State var loginScreenShow = false
    var imageCircle: UIImage? {
        userService.userImage
    }
    
    var body: some View {

        ZStack {
            
            
            ZStack {
                switch appService.shownScreen {
                case .onboarding:
                    OnboardingView()
                        .onAppear {
                            appService.showTabBar = false
                        }
                case .allJokes:
                    AllJokesView()
                case .favorites:
                    FavoritesView()
                case .myJokes:
                    SendJokeView()
                case .settings:
                    SettingsView()
                case .account:
                    AccountView()
                }
            }
            // picturecicle
            .overlay(alignment: .topTrailing) {
                if appService.shownScreen != .onboarding && appService.shownScreen != .account {
                    pictureCircle
                }
            }
            // tabbar
            .overlay(alignment: .bottom) {
                Group {
                    if appService.showTabBar {
                        HStack {
                            TabBarButton(
                                label: "Все шутки",
                                icon: "list.bullet",
                                isSelected: appService.shownScreen == .allJokes
                            ) {
                                appService.shownScreen = .allJokes
                            }
                            
                            TabBarButton(
                                label: "Избранное",
                                icon: "heart",
                                isSelected: appService.shownScreen == .favorites
                            ) {
                                appService.shownScreen = .favorites
                            }
                            
                            TabBarButton(
                                label: "Мои шутки",
                                icon: "person",
                                isSelected: appService.shownScreen == .myJokes
                            ) {
                                appService.shownScreen = .myJokes
                                
                            }
                            
                            TabBarButton(
                                label: "Настройки",
                                icon: "gearshape",
                                isSelected: appService.shownScreen == .settings
                            ) {
                                appService.shownScreen = .settings
                            }
                        }
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(20)
                        .offset(y: loginScreenShow ? 300 : 0)
                    }
                }
                .rotation3DEffect(
                    Angle(degrees: loginScreenShow ? 40 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
                .blur(radius: loginScreenShow ? 10 : 0)
                
                .animation(.spring(duration: 2), value: loginScreenShow)
            }
            .blur(radius: userService.loaded ? 0 : 5)
            // Показываем LoadingView поверх всего контента во время инициализации
            if !userService.loaded {
                LoadingView()
                    .transition(.opacity)
            }
            
        }
        .frame(width: .infinity, height: .infinity)
        .animation(.spring(duration: 1), value: userService.loaded)
        
        
    
    }
    
    var pictureCircle: some View {
        
        Button {
            appService.shownScreen = .account
            appService.showTabBar = false
        } label: {
            if let image = imageCircle {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                    .aspectRatio(1/1, contentMode: .fit)
                    .clipped()
                    .frame(height: 40)
                    .clipped()
                    .mask { RoundedRectangle(cornerRadius: 74, style: .continuous) }
                    .overlay {
                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                            .stroke(.white, lineWidth: 3)
                            .background(RoundedRectangle(cornerRadius: 50, style: .continuous).fill(.clear))
                    }
                    .padding()
            } else {
                Image("noImage")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                    .aspectRatio(1/1, contentMode: .fit)
                    .clipped()
                    .frame(height: 40)
                    .clipped()
                    .mask { RoundedRectangle(cornerRadius: 74, style: .continuous) }
                    .overlay {
                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                            .stroke(.white, lineWidth: 3)
                            .background(RoundedRectangle(cornerRadius: 50, style: .continuous).fill(.clear))
                    }
                    .padding()
            }
        }


        
        
        
    }
    
}



#Preview {
    TabBarView()
    //    TestAnimationView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}



struct TestAnimationView: View {
    
    @EnvironmentObject var appService: AppService
    @State var show = false
    var body: some View {
        ZStack {
            
//            LoginScreenView()
            
            Button("Toggle TabBar") {
                //                withAnimation(.spring(duration: 3)) {
                appService.showTabBar.toggle()
                //                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                //                    show.toggle()
                //                })
                //                }
            }
            
            if appService.showTabBar {
                TestView()
                //                    .opacity(show ? 1 : 0)
                
                    .zIndex(10)
                    .transition(AnyTransition.move(edge: .bottom))
                    .offset(y: appService.showTabBar ? 0 : 2000)
                
                
                
            }
            
            
        }
        .animation(.spring(duration: 3), value: appService.showTabBar)
    }
}

struct TestView: View {
    
    @EnvironmentObject var appService: AppService
    
    var body: some View {
        ZStack {
            
            Text("Hello, TabBar!")
                .padding()
            
        }
        .frame(width: 300, height: 300)
        .background(Color.yellow)
        .cornerRadius(10)
        .onTapGesture {
            //            withAnimation(.spring(duration: 3)) {
            appService.showTabBar.toggle()
            //            }
        }
        
    }
}
