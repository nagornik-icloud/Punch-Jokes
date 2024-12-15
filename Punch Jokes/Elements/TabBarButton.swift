//
//  TabBarButton.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 20.12.24..
//

import SwiftUI

struct TabBarButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isSelected ? .blue : .gray)

            Text(label)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(10)
        .onTapGesture {
            action()
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(AppService())
        .environmentObject(JokeService())
        .environmentObject(UserService())
        .preferredColorScheme(.dark)
}
