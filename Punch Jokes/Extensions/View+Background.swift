import SwiftUI

extension View {
    func appBackground() -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color.purple.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    func glassBackground() -> some View {
        self.padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
