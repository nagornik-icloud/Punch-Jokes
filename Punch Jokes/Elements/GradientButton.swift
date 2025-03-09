//
//  GradientButton.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 13.1.25..
//

import SwiftUI

struct GradientButton: View {
    @State private var isPressed = false
    @State private var buttonSize: CGSize = .zero
    
    var name: String = "Button"
    var width: CGFloat = 165
    var height: CGFloat = 36
    var action: () -> Void
    
    var body: some View {
        ZStack {
            // Background Glow Effect
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 255/255, green: 94/255, blue: 247/255),
                            Color(red: 2/255, green: 245/255, blue: 255/255)
                        ]),
                        center: .init(x: 0.1, y: 0.2),
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .blur(radius: 15)
                .opacity(isPressed ? 1 : 0.7) // Match the glow effect with button state
                .allowsHitTesting(false)
                
//                .padding(-200)
                .frame(width: buttonSize.width + 5, height: buttonSize.height + 5)
            
            // Button
            buttonItself
                .background(GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        buttonSize = geometry.size
                                    }
                                    .onChange(of: geometry.size) { newSize in
                                        buttonSize = newSize
                                    }
                            })
        }
        .animation(.easeInOut(duration: 0.5), value: isPressed)
//        .frame(width: 165, height: 62) // Ensure everything aligns
        .onTapGesture {
            withAnimation(.spring(duration: 0.5)) {
                hapticFeedback()
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPressed = false
                    action()
                }
            }
            
        }
//        .frame(width: width, height: height)
    }
    
    var buttonItself: some View {
        Text(name)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 36)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isPressed ?
                            AnyShapeStyle(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 255/255, green: 94/255, blue: 247/255),
                                        Color(red: 2/255, green: 245/255, blue: 255/255)
                                    ]),
                                    center: .init(x: 0.1, y: 0.2),
                                    startRadius: 10,
                                    endRadius: 200
                                )
                            )
                            : AnyShapeStyle(Color(red: 16/255, green: 7/255, blue: 32/255))
                    )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .rotationEffect(.degrees(isPressed ? 3 : 0))
    }
    
}

#Preview {
    GradientButton(name: NSLocalizedString("Добавить панч", comment: "Add Punchline")) {
        print("Button tapped")
    }
    .preferredColorScheme(.dark)
}
