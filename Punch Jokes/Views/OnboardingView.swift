import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                OnboardingPageView(
                    title: "Learn design & code",
                    subtitle: "Don’t skip design. Learn design and code, by building real apps with SwiftUI.",
                    imageName: "lightbulb.fill",
                    gradient: Gradient(colors: [Color.purple, Color.blue])
                )
                .tag(0)
                
                OnboardingPageView(
                    title: "Boost your skills",
                    subtitle: "Access hundreds of resources to take your design and coding skills to the next level.",
                    imageName: "sparkles",
                    gradient: Gradient(colors: [Color.pink, Color.orange])
                )
                .tag(1)
                
                OnboardingPageView(
                    title: "Get started now!",
                    subtitle: "Start building apps that matter. Let’s make something great together!",
                    imageName: "checkmark.seal.fill",
                    gradient: Gradient(colors: [Color.blue, Color.green])
                )
                .tag(2)
                
                LoginScreenView(onTapX: {
                    
                })
                .tag(3)
                
                
            }
            .tabViewStyle(PageTabViewStyle())
        }
    }
}

struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let imageName: String
    let gradient: Gradient
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 40)
            
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(Circle())
                )
                .shadow(radius: 10)
            
            Spacer()
        }
    }
}


#Preview {
    OnboardingView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
