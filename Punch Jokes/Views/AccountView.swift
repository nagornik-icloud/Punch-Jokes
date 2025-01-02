//
//  AccountView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 29.12.24..
//

import SwiftUI
import PhotosUI

struct AccountView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var jokeService: JokeService
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showLogoutAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isEditingUsername = false
    @State private var newUsername = ""
    @State private var isUploadingImage = false
    
    private var userJokesCount: Int {
        guard let userId = userService.currentUser?.id else { return 0 }
        return jokeService.jokes.filter { $0.authorId == userId }.count
    }
    
    private var favoriteJokesCount: Int {
        userService.currentUser?.favouriteJokesIDs?.count ?? 0
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let user = userService.currentUser {
                    accountContent(for: user)
                } else {
                    ContentUnavailableView("Войдите в аккаунт",
                        systemImage: "person.crop.circle",
                        description: Text("Чтобы увидеть свой профиль")
                    )
                }
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
        }
    }
    
    @ViewBuilder
    private func accountContent(for user: User) -> some View {
        Form {
            profileImageSection(for: user)
            userInfoSection(for: user)
            statisticsSection
            logoutSection
        }
        .overlay {
            if userService.isLoading || isUploadingImage {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    @ViewBuilder
    private func profileImageSection(for user: User) -> some View {
        Section {
            HStack {
                Spacer()
                ZStack {
                    profileImage(for: user)
                    if isUploadingImage {
                        ProgressView()
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding(.vertical)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Изменить фото", systemImage: "photo")
            }
            .disabled(isUploadingImage)
        }
    }
    
    @ViewBuilder
    private func profileImage(for user: User) -> some View {
        if let image = jokeService.authorImages[user.id] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String(user.username?.prefix(1).uppercased() ?? ""))
                        .font(.title)
                        .foregroundColor(.gray)
                )
        }
    }
    
    @ViewBuilder
    private func userInfoSection(for user: User) -> some View {
        Section("Информация") {
            if isEditingUsername {
                TextField("Имя пользователя", text: $newUsername)
                    .onSubmit(updateUsername)
            } else {
                HStack {
                    Text("Имя")
                    Spacer()
                    Text(user.username ?? "Не указано")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    newUsername = user.username ?? ""
                    isEditingUsername = true
                }
            }
            
            HStack {
                Text("Email")
                Spacer()
                Text(user.email)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var statisticsSection: some View {
        Section("Статистика") {
            HStack {
                Text("Мои шутки")
                Spacer()
                Text("\(userJokesCount)")
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("В избранном")
                Spacer()
                Text("\(favoriteJokesCount)")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutAlert = true
            } label: {
                Text("Выйти")
            }
        }
    }
    
    private func updateUsername() {
        guard !newUsername.isEmpty else { return }
        
        Task {
            do {
                userService.currentUser?.username = newUsername
                try await userService.saveUserToFirestore()
                isEditingUsername = false
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
                // Сбрасываем выбранное изображение на главном потоке
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
                try? await jokeService.uploadAuthorImage(resizedImage, userId: userService.currentUser?.id ?? "")
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
