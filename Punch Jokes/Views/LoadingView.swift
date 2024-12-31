//
//  LoadingView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 30.12.24..
//

import SwiftUI

struct LoadingView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    
    var body: some View {
        ZStack {
            // Фоновый градиент
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.purple.opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Анимированные круги на фоне
            ForEach(0..<3) { index in
                Circle()
                    .stroke(lineWidth: 2)
                    .frame(width: 100 + CGFloat(index * 40))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.purple.opacity(0.5), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(rotation + Double(index * 30)))
                    .offset(y: -30)
            }
            
            VStack(spacing: 30) {
                // Кастомный спиннер
                ZStack {
                    Circle()
                        .stroke(lineWidth: 4)
                        .frame(width: 60)
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            .linearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60)
                        .rotationEffect(.degrees(rotation))
                }
                
                // Текст с градиентом
                Text("Loading")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.white, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(scale)
            }
            .blur(radius: 0.5)
        }
        .onAppear {
            // Анимация вращения
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Пульсирующая анимация текста
            withAnimation(.easeInOut(duration: 1).repeatForever()) {
                scale = 1.1
            }
        }
    }
}

#Preview {
    LoadingView()
}
