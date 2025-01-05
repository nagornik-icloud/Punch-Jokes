import Foundation
import FirebaseFirestore
import FirebaseCore
import SwiftUI

// MARK: - JSON Models
private struct JsonJoke: Codable {
    let setup: String
    let punchline: String
}

private struct JsonData: Codable {
    let jokes: [JsonJoke]
}

// MARK: - Helper Functions
private func randomDate2024() -> Date {
    let calendar = Calendar.current
    let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
    let endDate = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
    let randomTimeInterval = TimeInterval.random(in: startDate.timeIntervalSince1970...endDate.timeIntervalSince1970)
    return Date(timeIntervalSince1970: randomTimeInterval)
}

private func generateAdditionalPunchlines(originalJoke: String) -> [String] {
    let punchlines = [
        "Это было неожиданно!",
        "Вот это поворот!",
        "Не могу перестать смеяться",
        "Классика жанра",
        "Это гениально",
        "Продолжай в том же духе",
        "Ха-ха, отличная шутка",
        "Это что-то новенькое",
        "Браво!",
        "Вот это да!",
        "Не ожидал такого финала",
        "Это стоило прочитать",
        "Просто супер",
        "Отличное завершение",
        "Великолепно!"
    ]
    
    let count = Int.random(in: 0...13)
    return Array(punchlines.shuffled().prefix(count))
}

// MARK: - Migration Service
enum MigrationError: Error {
    case jsonLoadFailed
    case jsonDecodeFailed
}

final class DataMigrationService {
    static let shared = DataMigrationService()
    private init() {}
    
    private let authorId = "IpxCc4U4c9RuufyYJRmfZtvbUmE3"
    private var migrationCallback: ((String) -> Void)?
    
    func migrate(progressCallback: @escaping (String) -> Void) async throws {
        self.migrationCallback = progressCallback
        
        // Загрузка данных из JSON
        let jsonContent = try await loadJSONData()
        updateStatus("📖 Загружено \(jsonContent.jokes.count) шуток из JSON")
        
        // Удаление существующих данных
        try await deleteExistingData()
        updateStatus("✅ Существующие шутки удалены")
        
        // Создание новых шуток
        try await createNewJokes(from: jsonContent)
        updateStatus("✅ Миграция успешно завершена!")
    }
    
    private func updateStatus(_ status: String) {
        Task { @MainActor in
            migrationCallback?(status)
        }
    }
    
    private func loadJSONData() async throws -> JsonData {
        guard let path = Bundle.main.path(forResource: "jokes", ofType: "json") else {
            throw MigrationError.jsonLoadFailed
        }
        
        let jsonString = try String(contentsOfFile: path, encoding: .utf8)
        guard let jsonData = jsonString.data(using: .utf8),
              let content = try? JSONDecoder().decode(JsonData.self, from: jsonData) else {
            throw MigrationError.jsonDecodeFailed
        }
        
        return content
    }
    
    private func deleteExistingData() async throws {
        updateStatus("🗑 Удаляем существующие шутки...")
        let db = Firestore.firestore()
        let batch = db.batch()
        let jokesSnapshot = try await db.collection("jokes").getDocuments()
        
        for document in jokesSnapshot.documents {
            let punchlinesSnapshot = try await document.reference.collection("punchlines").getDocuments()
            for punchline in punchlinesSnapshot.documents {
                batch.deleteDocument(punchline.reference)
            }
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
    
    private func createNewJokes(from data: JsonData) async throws {
        updateStatus("📝 Создаем новые шутки...")
        let db = Firestore.firestore()
        
        for (index, joke) in data.jokes.enumerated() {
            let jokeId = UUID().uuidString
            let jokeRef = db.collection("jokes").document(jokeId)
            
            // Создаем шутку
            try await jokeRef.setData([
                "id": jokeId,
                "setup": joke.setup,
                "status": "approved",
                "authorId": authorId,
                "createdAt": Timestamp(date: randomDate2024()),
                "views": Int.random(in: 0...20000),
                "likes": Int.random(in: 0...100),
                "dislikes": Int.random(in: 0...100)
            ])
            
            // Добавляем оригинальный панчлайн
            let originalPunchlineId = UUID().uuidString
            try await jokeRef.collection("punchlines").document(originalPunchlineId).setData([
                "id": originalPunchlineId,
                "text": joke.punchline,
                "likes": Int.random(in: 0...100),
                "dislikes": Int.random(in: 0...100),
                "status": "approved",
                "authorId": authorId,
                "createdAt": Timestamp(date: randomDate2024())
            ])
            
            // Добавляем дополнительные панчлайны
            for punchline in generateAdditionalPunchlines(originalJoke: joke.punchline) {
                let punchlineId = UUID().uuidString
                try await jokeRef.collection("punchlines").document(punchlineId).setData([
                    "id": punchlineId,
                    "text": punchline,
                    "likes": Int.random(in: 0...100),
                    "dislikes": Int.random(in: 0...100),
                    "status": "approved",
                    "authorId": authorId,
                    "createdAt": Timestamp(date: randomDate2024())
                ])
            }
            
            updateStatus("⏳ Обработано \(index + 1)/\(data.jokes.count) шуток")
        }
    }
}

// MARK: - Migration View
struct DataMigrationView: View {
    @State private var isLoading = false
    @State private var status = "Готов к миграции"
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            Text(status)
                .multilineTextAlignment(.center)
                .padding()
            
            if !isLoading {
                Button("Начать миграцию") {
                    startMigration()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func startMigration() {
        Task { @MainActor in
            isLoading = true
            status = "Начинаем миграцию..."
            
            do {
                try await DataMigrationService.shared.migrate { status in
                    self.status = status
                }
            } catch {
                status = "❌ Ошибка: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

// MARK: - Preview
struct DataMigrationPreview: PreviewProvider {
    static var previews: some View {
        DataMigrationView()
    }
}
