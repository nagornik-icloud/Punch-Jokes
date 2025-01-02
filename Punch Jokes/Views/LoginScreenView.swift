import SwiftUI
import FirebaseAuth

struct LoginScreenView: View {
    @EnvironmentObject var userService: UserService
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isRegistering = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appService: AppService
    
    let onTapX: () -> Void
    
    var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.purple,
                Color.blue
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Logo или заголовок
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.purple)
                    
                    Text(isRegistering ? "Create Account" : "Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(isRegistering ? "Sign up to get started" : "Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 30)
                
                // Поля ввода
                VStack(spacing: 20) {
                    // Email field
                    HStack(spacing: 15) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    if isRegistering {
                        // Username field
                        HStack(spacing: 15) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                            TextField("Username", text: $username)
                                .textContentType(.username)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Password field
                    HStack(spacing: 15) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        SecureField("Password", text: $password)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 15) {
                    if userService.isLoading {
                        ProgressView()
                    } else {
                        Button(action: performAction) {
                            HStack {
                                Image(systemName: isRegistering ? "person.badge.plus" : "arrow.right.circle")
                                Text(isRegistering ? "Sign Up" : "Sign In")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(color: Color.purple.opacity(0.3), radius: 5, y: 3)
                        }
                        .disabled(email.isEmpty || password.isEmpty || (isRegistering && username.isEmpty))
                        .opacity(email.isEmpty || password.isEmpty || (isRegistering && username.isEmpty) ? 0.6 : 1)
                        
                        Button(action: { withAnimation { isRegistering.toggle() }}) {
                            Text(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.purple)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    )
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func performAction() {
        isLoading = true
        
        Task {
            do {
                if isRegistering {
//                    try await userService.registerUser(email: email, password: password, username: username)
                } else {
//                    try await userService.login(email: email, password: password)
                }
                await MainActor.run {
                    isLoading = false
                    appService.closeAccScreen()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginScreenView(onTapX: {})
        .environmentObject(UserService())
        .environmentObject(AppService())
        .preferredColorScheme(.dark)
}
