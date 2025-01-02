import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userService: UserService
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingResetPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Вход")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
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
                }
                .padding(.horizontal)
                
                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Войти")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: Color.blue.opacity(0.3), radius: 5, y: 3)
                .padding(.horizontal)
                
                NavigationLink("Нет аккаунта? Зарегистрируйтесь", destination: RegisterView())
                    .foregroundColor(.blue)
                
                Spacer()
            }
            .padding(.top, 50)
            .appBackground()
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Сброс пароля", isPresented: $showingResetPassword) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                Button("Отмена", role: .cancel) { }
                Button("Сбросить") {
                    resetPassword()
                }
            } message: {
                Text("Введите email для сброса пароля")
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        Task {
            do {
                try await userService.login(email: email, password: password)
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
    
    private func resetPassword() {
        guard !email.isEmpty else {
            alertTitle = "Ошибка"
            alertMessage = "Введите email"
            showingAlert = true
            return
        }
        
        Task {
            do {
                try await userService.resetPassword(email: email)
                alertTitle = "Успешно"
                alertMessage = "Инструкции по сбросу пароля отправлены на ваш email"
                showingAlert = true
            } catch {
                alertTitle = "Ошибка"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}
