//
//  AccountView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 29.12.24..
//

import SwiftUI

struct AccountView: View {
    
    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    
    
    var body: some View {
        
        if userService.currentUser != nil {
            UserProfileView()
        } else {
            LoginScreenView {
                appService.shownScreen = appService.lastScreen
                appService.showTabBar = true
            }
        }
        
        

        
        
        
        
        
        
        
        
        
        
    }
    
    var account: some View {
        
        Text("account")
        
    }
    
    
}

#Preview {
    AccountView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}

import SwiftUI
import Firebase
import FirebaseStorage

struct UserProfileView: View {
    
    @State private var userImage: UIImage? = nil
    @State private var fetchedImage: UIImage? = nil // Для проверки изменений
    
    @State private var userName: String = ""
    @State private var userNickname: String = ""
    @State private var userEmail: String = ""
    
    @State private var isEditing: Bool = false
    @State private var isImagePickerPresented: Bool = false

    @EnvironmentObject var jokeService: JokeService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var appService: AppService
    
    let storage = Storage.storage()
//    let imageCachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    
    var body: some View {
            VStack(spacing: 20) {
                // User photo
                ZStack {
                    if let image = userImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(Text("Add Photo").foregroundColor(.gray))
                    }
                }
                .onTapGesture {
                    isImagePickerPresented = true
                    isEditing = true
                }
                .sheet(isPresented: $isImagePickerPresented) {
                    ImagePicker(selectedImage: $userImage, onSave: { image in
                        userImage = image
                    })
                }
                
                // User info
                VStack(alignment: .leading, spacing: 10) {
                    EditableTextField(label: "Name", text: $userName, isEditing: isEditing)
                    EditableTextField(label: "Nickname", text: $userNickname, isEditing: isEditing)
                    EditableTextField(label: "Email", text: $userEmail, isEditing: isEditing)
                }
                .padding(.horizontal, 20)
                
                // Save Button
                Button {
                    isEditing.toggle()
                    if !isEditing {
                        saveChanges()
                    }
                } label: {
                    Text(isEditing ? "Save Changes" : "Edit Profile")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isEditing ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                
                Button {
                    userService.logoutUser { _ in
                        
                    }
                } label: {
                    Text("Log out")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isEditing ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                
//                Button {
//                    appService.closeAccScreen()
//                } label: {
//                    Text("Close")
//                        .font(.headline)
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(isEditing ? Color.blue : Color.gray)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                }
//                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
            .overlay(alignment: .topTrailing) {
                
                
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 5)
                    .onTapGesture {
                        appService.closeAccScreen()
                    }
                
                
            }
            
            .onAppear(perform: loadUserData)
    }
    
    // MARK: - Methods
    
    
//    func saveImageToCache(image: UIImage) {
////        let filePath = getLocalImagePath()
//        let filePath = userService.getLocalImagePath()
//        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
//        do {
//            try data.write(to: filePath)
//            print("Image saved locally at \(filePath)")
//        } catch {
//            print("Error saving image locally: \(error.localizedDescription)")
//        }
//    }
    
//    func loadImageFromCache() -> UIImage? {
//        let filePath = getLocalImagePath()
//        if FileManager.default.fileExists(atPath: filePath.path) {
//            return UIImage(contentsOfFile: filePath.path)
//        }
//        return nil
//    }
//    func getLocalImagePath() -> URL {
//        return imageCachePath.appendingPathComponent("\(userService.currentUser?.id ?? "default_user").jpg")
//    }
    
    func uploadImage(image: UIImage) {
        // Уменьшаем вес изображения
        guard let imageData = image.jpegData(compressionQuality: 0.2) else { return }
        let imagePath = "user_photos/\(userService.currentUser?.id ?? "random").jpg"
        let ref = storage.reference().child(imagePath)
        
        ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
            } else {
                print("Image uploaded successfully!")
                userService.saveImageToCache(image: image) // Сохраняем изображение в кэш после загрузки
            }
        }
    }
    
    func loadUserData() {
        // Сначала пытаемся загрузить изображение из кэша
        if let cachedImage = userService.loadImageFromCache() {
            print("Loaded image from cache")
            userImage = cachedImage
        } else {
            // Если изображения в кэше нет, загружаем из Firebase
            let imagePath = "user_photos/\(userService.currentUser?.id ?? "random").jpg"
            let ref = storage.reference().child(imagePath)
            
            ref.getData(maxSize: Int64(2 * 1024 * 1024)) { data, error in
                if let error = error {
                    print("Error fetching image: \(error.localizedDescription)")
                } else if let data = data, let image = UIImage(data: data) {
                    print("Loaded image from Firebase")
                    userImage = image
                    userService.saveImageToCache(image: image) // Сохраняем изображение локально
                }
            }
        }
        
        // Загружаем другую пользовательскую информацию
        userName = userService.currentUser?.name ?? "default"
        userEmail = userService.currentUser?.email ?? "default"
        userNickname = userService.currentUser?.username ?? "default"
    }
    
    func saveChanges() {
        // Загружаем изображение, если оно изменено
        if userImage != fetchedImage, let updatedImage = userImage {
            uploadImage(image: updatedImage)
        }
        userService.currentUser?.email = userEmail
        userService.currentUser?.name = userName
        userService.currentUser?.username = userNickname
        userService.saveUserToFirestore(userService.currentUser!) { _ in
            
        }
        // Сохранение других данных (например, в Firebase Realtime Database или Firestore)
        print("Changes saved for:")
        print("Name: \(userName), Nickname: \(userNickname), Email: \(userEmail)")
    }
}


// MARK: - Subviews
struct EditableTextField: View {
    let label: String
    @Binding var text: String
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            if isEditing {
                TextField("Enter \(label.lowercased())", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(text)
                    .font(.body)
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
            picker.dismiss(animated: true, completion: nil)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
