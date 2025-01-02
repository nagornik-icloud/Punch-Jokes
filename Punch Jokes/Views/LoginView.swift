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
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Пароль", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button {
                        login()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Войти")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    
                    Button("Забыли пароль?") {
                        showingResetPassword = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Вход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
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
