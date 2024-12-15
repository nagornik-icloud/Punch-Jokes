//
//  MyJokesView.swift
//  Punch Jokes
//
//  Created by Anton Nagornyi on 16.12.24..
//

import SwiftUI

struct MyJokesView: View {
    @State private var newJoke = Joke(id: UUID().uuidString, setup: "", punchline: "", status: "")
    @State private var isSuccess = false
    @State private var isButtonDisabled = false
    @State private var timer: Int = 5 // Начальное значение таймера 5 секунд

    let jokeService = JokeService()

    // Проверяем, что оба поля заполнены и текст длиннее 3 символов
    var isFormValid: Bool {
        !newJoke.setup.isEmpty && !newJoke.punchline.isEmpty && newJoke.setup.count > 3 && newJoke.punchline.count > 3
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Введите setup", text: $newJoke.setup)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 5)
                .padding([.leading, .trailing])

            TextField("Введите punchline", text: $newJoke.punchline)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 5)
                .padding([.leading, .trailing])

            Button(action: sendJoke) {
                Text("Отправить на премодерацию")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isButtonDisabled ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .opacity(isButtonDisabled ? 0.5 : 1.0)
            }
            .disabled(!isFormValid || isButtonDisabled) // Кнопка неактивна, если форма невалидна или в процессе отправки

            if isSuccess {
                Text("Шутка успешно отправлена!")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }

            if isButtonDisabled {
                // Анимация таймера
                Text("Подождите \(timer) секунд...")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .transition(.opacity) // Анимация появления текста
                    .animation(.easeInOut(duration: 0.5), value: timer)
            }
        }
        .padding()
        .onChange(of: isButtonDisabled) { newValue in
            if newValue {
                startTimer()
            }
        }
    }

    // Функция для отправки шутки
    private func sendJoke() {
        jokeService.addJokeForModeration(joke: newJoke) { success in
            isSuccess = success
            if success {
                // Очищаем поля после успешной отправки
                newJoke = Joke(id: UUID().uuidString, setup: "", punchline: "", status: "pending")
                isButtonDisabled = true
            }
        }
    }

    // Таймер для деактивации кнопки
    private func startTimer() {
        // Используем DispatchQueue для асинхронного отсчета
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.timer > 0 {
                self.timer -= 1
                startTimer() // Рекурсия для уменьшения таймера
            } else {
                self.isButtonDisabled = false // Разрешаем кнопку снова
                self.timer = 5 // Сбрасываем таймер на 5 секунд
            }
        }
    }
}

struct MyJokesView_Previews: PreviewProvider {
    static var previews: some View {
        MyJokesView()
    }
}
