import SwiftUI
import PhotosUI

struct AccountView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    
    var body: some View {
        if let user = userService.currentUser {
            UserProfileView(user: user)
        } else {
            AccountLoginView()
        }
    }
}

struct AccountLoginView: View {
    
    @EnvironmentObject var appService: AppService
    @EnvironmentObject var userService: UserService
    
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                    
                    Text("Добро пожаловать")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Войдите в аккаунт чтобы продолжить")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
                
                // Login Form
                VStack(spacing: 15) {
                    CustomTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        isEditing: true,
                        onFocusChange: { isFocused in
                            if isFocused {
                                focusedField = .email
                            }
                        }
                    )
                    
                    CustomTextField(
                        icon: "lock.fill",
                        placeholder: "Пароль",
                        text: $password,
                        isEditing: true,
                        onFocusChange: { isFocused in
                            if isFocused {
                                focusedField = .password
                            }
                        }
                    )
                }
                .padding(.horizontal)
                
                // Login Button
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Войти")
                            .fontWeight(.semibold)
                            .frame(width: .infinity, height: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: Color.blue.opacity(0.3), radius: 5, y: 3)
                .padding(.horizontal)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
                .onTapGesture {
                    login()
                }
                
                // Register Button
                Button(action: { showRegister = true }) {
                    Text("Нет аккаунта? Зарегистрируйтесь")
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .appBackground()
            .navigationTitle("Профиль")
            .onTapGesture {
                focusedField = nil
                appService.showTabBar = true
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
    
    private func login() {
        isLoading = true
        Task {
            do {
                try await userService.login(email: email, password: password)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct UserProfileView: View {
    let user: User
    
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var appService: AppService
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showLogoutAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isEditing = false
    @State private var userName = ""
    @State private var userNickname = ""
    @State private var userEmail = ""
    @State private var isUploadingImage = false
    @State private var imageScale: CGFloat = 1.0
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case name, nickname, email
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    private var userJokesCount: Int {
        jokeService.jokes.filter { $0.authorId == user.id }.count
    }
    
    private var favoriteJokesCount: Int {
        user.favouriteJokesIDs?.count ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Profile Image Section
                profileImageSection
                
                // Statistics Section
                statsSection
                
                // User Info Section
                VStack(spacing: 20) {
                    CustomTextField(
                        icon: "person.fill",
                        placeholder: "Имя",
                        text: $userName,
                        isEditing: isEditing,
                        onFocusChange: { isFocused in
                            if isFocused {
                                focusedField = .name
                            }
                        }
                    )
                    
                    CustomTextField(
                        icon: "at",
                        placeholder: "Никнейм",
                        text: $userNickname,
                        isEditing: isEditing,
                        onFocusChange: { isFocused in
                            if isFocused {
                                focusedField = .nickname
                            }
                        }
                    )
                    
                    CustomTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $userEmail,
                        isEditing: isEditing,
                        onFocusChange: { isFocused in
                            if isFocused {
                                focusedField = .email
                            }
                        }
                    )
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button(action: {
                        withAnimation {
                            if isEditing {
                                saveChanges()
                            }
                            isEditing.toggle()
                            focusedField = nil
                        }
                    }) {
                        HStack {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            Text(isEditing ? "Сохранить" : "Редактировать")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEditing ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: (isEditing ? Color.green : Color.blue).opacity(0.3), radius: 5, y: 3)
                    }
                    
                    Button(action: { showLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: Color.red.opacity(0.3), radius: 5, y: 3)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 30)
        }
        .onTapGesture {
            focusedField = nil
            appService.showTabBar = true
        }
        .navigationTitle("Профиль")
        .alert("Ошибка", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Выйти", isPresented: $showLogoutAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Выйти", role: .destructive) {
                logout()
            }
        } message: {
            Text("Вы уверены, что хотите выйти?")
        }
        .onChange(of: selectedItem) { _ in
            updateProfileImage()
        }
        .onAppear(perform: loadUserData)
    }
    
    private var profileImageSection: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 140, height: 140)
                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
            
            if let image = jokeService.authorImages[user.id] {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                    .scaleEffect(imageScale)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundColor(.gray)
                    .scaleEffect(imageScale)
            }
            
            if isUploadingImage {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                
                ProgressView()
                    .controlSize(.large)
                    .tint(.blue)
            } else if isEditing {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        )
                        .opacity(0.7)
                }
                .disabled(isUploadingImage)
            }
        }
        .onTapGesture {
            if isEditing {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    imageScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        imageScale = 1.0
                    }
                }
            }
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 40) {
            VStack {
                Text("\(userJokesCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Шутки")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .glassBackground()
            
            VStack {
                Text("\(favoriteJokesCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Избранное")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .glassBackground()
        }
    }
    
    private func loadUserData() {
        userName = user.name ?? ""
        userEmail = user.email
        userNickname = user.username ?? ""
    }
    
    private func saveChanges() {
        Task {
            do {
                userService.currentUser?.name = userName
                userService.currentUser?.username = userNickname
                userService.currentUser?.email = userEmail
                try await userService.saveUserToFirestore()
                isEditing = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func updateProfileImage() {
        guard let selectedItem = selectedItem else { return }
        
        Task {
            isUploadingImage = true
            defer {
                isUploadingImage = false
                DispatchQueue.main.async {
                    self.selectedItem = nil
                }
            }
            
            do {
                guard let data = try await selectedItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось загрузить изображение"])
                }
                
                let resizedImage = image.preparingThumbnail(of: CGSize(width: 300, height: 300)) ?? image
                try await jokeService.uploadAuthorImage(resizedImage, userId: user.id)
                try await jokeService.reloadAuthorImage(for: user.id)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func logout() {
        do {
            try userService.logOut()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isEditing: Bool
    @FocusState private var isFocused: Bool
    var onFocusChange: ((Bool) -> Void)?
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .disabled(!isEditing)
                .focused($isFocused)
                .onChange(of: isFocused) { newValue in
                    onFocusChange?(newValue)
                }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
