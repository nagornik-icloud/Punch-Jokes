import Foundation
import FirebaseFirestore

class Joke: Identifiable, Codable, Equatable {
    var id: String = ""
    var setup: String = ""
    var punchline: String = ""
    var status: String = ""
    var authorId: String = ""
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case setup
        case punchline
        case status
        case authorId
        case createdAt
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        setup = try container.decode(String.self, forKey: .setup)
        punchline = try container.decode(String.self, forKey: .punchline)
        status = try container.decode(String.self, forKey: .status)
        
        // Пробуем декодировать authorId
        if let author = try? container.decode(String.self, forKey: .authorId) {
            // Если authorId - это email, используем константный ID
            if author.contains("@") {
                authorId = id
            } else {
                authorId = author
            }
        }
        
        // Пробуем декодировать createdAt
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = Date() // Значение по умолчанию
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(setup, forKey: .setup)
        try container.encode(punchline, forKey: .punchline)
        try container.encode(status, forKey: .status)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(createdAt ?? Date(), forKey: .createdAt)
    }
    
    init() {}
    
    init(id: String, setup: String, punchline: String, status: String, authorId: String, createdAt: Date?) {
        self.id = id
        self.setup = setup
        self.punchline = punchline
        self.status = status
        self.authorId = authorId
        self.createdAt = createdAt
    }
    
    static func == (lhs: Joke, rhs: Joke) -> Bool {
        return lhs.id == rhs.id &&
               lhs.setup == rhs.setup &&
               lhs.punchline == rhs.punchline &&
               lhs.status == rhs.status &&
               lhs.authorId == rhs.authorId &&
               lhs.createdAt == rhs.createdAt
    }
}
