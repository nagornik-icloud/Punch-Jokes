import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userService: UserService
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var name = ""
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !username.isEmpty &&
        password == confirmPassword && password.count >= 6
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Регистрация")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                CustomTextField(
                    icon: "person.fill",
                    placeholder: "Имя",
                    text: $name,
                    isEditing: true
                )
                
                CustomTextField(
                    icon: "at",
                    placeholder: "Никнейм",
                    text: $username,
                    isEditing: true
                )
                
                CustomTextField(
                    icon: "envelope.fill",
                    placeholder: "Email",
                    text: $email,
                    isEditing: true
                )
                
                CustomTextField(
                    icon: "lock.fill",
                    placeholder: "Пароль",
                    text: $password,
                    isEditing: true
                )
                
                CustomTextField(
                    icon: "lock.fill",
                    placeholder: "Подтвердите пароль",
                    text: $confirmPassword,
                    isEditing: true
                )
            }
            .padding(.horizontal)
            
            Button(action: register) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Зарегистрироваться")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: Color.blue.opacity(0.3), radius: 5, y: 3)
            .padding(.horizontal)
            .disabled(!isFormValid || isLoading)
            
            Spacer()
        }
        .padding(.top, 50)
        .appBackground()
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func register() {
        isLoading = true
        
        Task {
            do {
                try await userService.register(email: email, password: password, username: username)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                alertTitle = "Ошибка"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            isLoading = false
        }
    }
}
