import SwiftUI

struct LoginScreenView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggedIn = false
    
    @State var inputsShow = false
    
//    @Binding var showXMark: Bool
    
//    @Binding var toShow: Bool
    var onTapX: () -> Void
    
    var body: some View {
        ZStack {
            
            VStack {
                Image("login-back")
                    .renderingMode(.original)
                    .resizable()
                    
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.size.width - 40, height: 700)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        // Hero
                        VStack(alignment: .leading, spacing: 11) {
                            Image("logo")
                                .renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, alignment: .topLeading)
                                .clipped()
                                .mask { RoundedRectangle(cornerRadius: 25, style: .continuous) }
                                .shadow(color: .black, radius: 8, x: 0, y: 4)
                            VStack(alignment: .leading, spacing: 11) {
                                Text("PunchJokes App")
                                    .font(.system(.largeTitle, design: .rounded, weight: .medium))
                                Text("""
                                     Войдите чтобы не потерять свои любимые шутки,
                                     а также отправлять шутки нам!
                                     """)
                                    .font(.system(.headline, weight: .medium))
                                    .frame(width: 240, alignment: .leading)
                                    .clipped()
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(Color.white)
                            .shadow(color: .black, radius: 3, x: 0, y: 4)
                        }
                        .padding()
                        .padding(.top, 42)
                    }
                    .overlay(alignment: .bottom) {
                        Group {
                            if !inputsShow {
                                VStack(spacing: 20) {
                                    Button(action: {
                                        // Логика для создания аккаунта
                                        inputsShow.toggle()
                                    }) {
                                        Text("Create Account")
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(12)
                                            .shadow(radius: 5)
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    Button(action: {
                                        // Логика для продолжения без регистрации
                                        userService.isFirstTime = false
                                        appService.shownScreen = .allJokes
                                        appService.showTabBar = true
                                    }) {
                                        Text("Continue as Guest")
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(UIColor(red: 0.20, green: 0.09, blue: 0.06, alpha: 1.00)))
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .shadow(radius: 5)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                    .mask {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                    }
                    .padding()
                    .shadow(color: Color(.sRGBLinear, red: 0/255, green: 0/255, blue: 0/255).opacity(0.15), radius: 18, x: 0, y: 14)
                
                Spacer()
                
                
                
            }
            .overlay(alignment: .topTrailing) {
                if appService.shownScreen != .onboarding{
                    
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(25)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 5)
                        .onTapGesture {
                            onTapX()
                        }
                    
                }
            }
            
            if inputsShow {
                VStack {
                    Spacer()
                    loginInputs
                        .padding()
                }
            }
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
//            appService.showTabBar = false
        }

    }
    
    var loginInputs: some View {
        VStack(spacing: 10) {
            
            Text("Вход")
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
            // Email Field
            TextField("Ваш email", text: $email)
                .colorScheme(.light)
                .padding()
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .keyboardType(.default)
                .autocapitalization(.none)


            // Password Field
            SecureField("Ваш пароль", text: $password)
                .colorScheme(.light)
                .padding()
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                
            
            // Log in Button
            Button(action: {
                // Add login action here
                print("Logging in with email: \(email) and password: \(password)")
                // Example: isLoggedIn = true // Simulate login
            }) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.blue)
                    .frame(height: 60)
                    .overlay {
                        Text("Войти")
                            .foregroundColor(.white)
                            .font(.system(.headline, design: .rounded))
                    }
//                        .padding(.horizontal, 40) // Same padding as the image width
            }
            .padding(.top, 20)
            
            Button {
                userService.loginUser(email: "nagorny.anton@gmail.com", password: "65151128") { result in
                    switch result {
                    case .success:
                        appService.showTabBar = true
                        print("User logged in: \(userService.currentUser?.email ?? "why noo current user?")")
                    case .failure(let error):
                        print("Error logging in: \(error.localizedDescription)")
                    }
                }
            } label: {
                Text("Быстрый вход")
                    .padding(.top)
                    .foregroundStyle(Color(.darkGray))
                    .font(.subheadline)
            }

            
        }
        .foregroundColor(Color.white)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 4)
        .padding()
        .background(.ultraThickMaterial.opacity(0.8))
        .cornerRadius(24)
        
//        .animation(.spring(.bouncy(duration: 4)), value: appService.showTabBar)
//        .offset(y: -120)
    }
    
}


#Preview {
    LoginScreenView(onTapX: {
        
    })
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}

