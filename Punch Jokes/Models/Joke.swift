import Foundation
import FirebaseFirestore

struct Joke: Identifiable, Codable, Hashable {
    var id: String?
    var setup: String
    var punchline: String
    var status: String
    var author: String
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case setup
        case punchline
        case status
        case author
        case createdAt
    }
    
    init(id: String? = nil, setup: String = "", punchline: String = "", status: String = "draft", author: String = "", createdAt: Date? = nil) {
        self.id = id
        self.setup = setup
        self.punchline = punchline
        self.status = status
        self.author = author
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        setup = try container.decode(String.self, forKey: .setup)
        punchline = try container.decode(String.self, forKey: .punchline)
        status = try container.decode(String.self, forKey: .status)
        author = try container.decode(String.self, forKey: .author)
        
        // Обработка даты из Firestore
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(setup, forKey: .setup)
        try container.encode(punchline, forKey: .punchline)
        try container.encode(status, forKey: .status)
        try container.encode(author, forKey: .author)
        
        // При сохранении в кэш используем ISO8601 формат
        if let date = createdAt {
            let formatter = ISO8601DateFormatter()
            try container.encode(formatter.string(from: date), forKey: .createdAt)
        }
    }
}
