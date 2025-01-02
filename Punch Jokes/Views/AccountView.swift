//
//  AccountView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 29.12.24..
//

import SwiftUI
import UIKit
import FirebaseStorage

struct AccountView: View {
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    var body: some View {
        if userService.currentUser != nil {
            UserProfileView()
        } else {
            LoginScreenView(onTapX: {
                
            })
                .onAppear {
                    appService.showTabBar = true
                }
        }
    }
}

struct UserProfileView: View {
    @State private var userName: String = ""
    @State private var userNickname: String = ""
    @State private var userEmail: String = ""
    @State private var isEditing: Bool = false
    @State private var isImagePickerPresented: Bool = false
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var imageScale: CGFloat = 1.0
    @State private var showingActionSheet = false
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
//    var backgroundGradient: LinearGradient {
//        LinearGradient(
//            gradient: Gradient(colors: [
//                Color(colorScheme == .dark ? .black : .white),
//                Color.purple.opacity(0.2)
//            ]),
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        )
//    }
    
    var body: some View {
        ZStack {
//            backgroundGradient
//                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Profile Image Section
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 140, height: 140)
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        if let userId = userService.currentUser?.id,
                           let image = jokeService.userPhotos[userId] {
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
                        
                        if isEditing {
                            Button(action: { showingActionSheet = true }) {
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
                            showingActionSheet = true
                        }
                    }
                    
                    // User Info Fields
                    VStack(spacing: 20) {
                        CustomTextField(
                            icon: "person.fill",
                            placeholder: "Name",
                            text: $userName,
                            isEditing: isEditing
                        )
                        
                        CustomTextField(
                            icon: "at",
                            placeholder: "Nickname",
                            text: $userNickname,
                            isEditing: isEditing
                        )
                        
                        CustomTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $userEmail,
                            isEditing: isEditing
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
                            }
                        }) {
                            HStack {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                                Text(isEditing ? "Save Changes" : "Edit Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isEditing ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(color: (isEditing ? Color.green : Color.blue).opacity(0.3), radius: 5, y: 3)
                        }
                        
                        Button(action: {
                            withAnimation {
                                isLoading = true
                                Task {
                                    do {
                                        try userService.signOut()
                                        isLoading = false
                                        appService.closeAccScreen()
                                    } catch {
                                        isLoading = false
                                        errorMessage = error.localizedDescription
                                        showError = true
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout")
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
            
            // Close Button
            // VStack {
            //     HStack {
            //         Spacer()
            //         Button(action: { appService.closeAccScreen() }) {
            //             Image(systemName: "xmark.circle.fill")
            //                 .font(.title)
            //                 .foregroundColor(.gray)
            //                 .padding()
            //                 .background(.ultraThinMaterial)
            //                 .clipShape(Circle())
            //                 .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            //         }
            //     }
            //     Spacer()
            // }
            // .padding()
            
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
        .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
            Button("Take Photo") {
                isImagePickerPresented = true
            }
            Button("Choose From Library") {
                isImagePickerPresented = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(selectedImage: .constant(nil)) { newImage in
                uploadImage(newImage)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear(perform: loadUserData)
    }
    
    private func loadUserData() {
        userName = userService.currentUser?.name ?? ""
        userEmail = userService.currentUser?.email ?? ""
        userNickname = userService.currentUser?.username ?? ""
    }
    
    private func saveChanges() {
        isLoading = true
        userService.currentUser?.email = userEmail
        userService.currentUser?.name = userName
        userService.currentUser?.username = userNickname
        
        if let user = userService.currentUser {
            Task {
                do {
                    try await userService.saveUserToFirestore(user)
                    await MainActor.run {
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        showError(message: "Failed to save changes: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            isLoading = false
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func uploadImage(_ image: UIImage) {
        guard let userId = userService.currentUser?.id,
              let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        
        Task {
            do {
                let imageRef = jokeService.storage.child("user_photos/\(userId).jpg")
                
                // Загружаем на сервер
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                
                // Обновляем локальный кэш
                await MainActor.run {
                    jokeService.userPhotos[userId] = image
                    jokeService.saveUserPhotoToCache(userId: userId, image: image)
                }
            } catch {
                print("Error updating user image: \(error)")
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onSave: (UIImage) -> Void
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onSave(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isEditing: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .disabled(!isEditing)
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

#Preview {
    AccountView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
