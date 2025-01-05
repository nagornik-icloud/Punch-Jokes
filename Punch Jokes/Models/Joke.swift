import Foundation
import FirebaseFirestore

struct Punchline: Identifiable, Codable, Equatable {
    var id: String = ""
    var text: String = ""
    var likes: Int = 0
    var dislikes: Int = 0
    var status: String = ""
    var authorId: String = ""
    var createdAt: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case likes
        case dislikes
        case status
        case authorId
        case createdAt
    }
    
    init() {}
    
    init(id: String, text: String, likes: Int = 0, dislikes: Int = 0, status: String, authorId: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.likes = likes
        self.dislikes = dislikes
        self.status = status
        self.authorId = authorId
        self.createdAt = createdAt
    }
}

struct Joke: Identifiable, Codable, Equatable {
    var id: String = ""
    var setup: String = ""
    var punchlines: [Punchline] = []
    var status: String = ""
    var authorId: String = ""
    var createdAt: Date = Date()
    var views: Int = 0
    var likes: Int = 0
    var dislikes: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id
        case setup
        case punchlines
        case status
        case authorId
        case createdAt
        case views
        case likes
        case dislikes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        setup = try container.decode(String.self, forKey: .setup)
        punchlines = try container.decodeIfPresent([Punchline].self, forKey: .punchlines) ?? []
        status = try container.decode(String.self, forKey: .status)
        
        if let author = try? container.decode(String.self, forKey: .authorId) {
            if author.contains("@") {
                authorId = id
            } else {
                authorId = author
            }
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        }
        
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        dislikes = try container.decodeIfPresent(Int.self, forKey: .dislikes) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(setup, forKey: .setup)
        try container.encode(punchlines, forKey: .punchlines)
        try container.encode(status, forKey: .status)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(views, forKey: .views)
        try container.encode(likes, forKey: .likes)
        try container.encode(dislikes, forKey: .dislikes)
    }
    
    init() {}
    
    init(id: String, setup: String, status: String, authorId: String, createdAt: Date, views: Int = 0, likes: Int = 0, dislikes: Int = 0) {
        self.id = id
        self.setup = setup
        self.status = status
        self.authorId = authorId
        self.createdAt = createdAt
        self.views = views
        self.likes = likes
        self.dislikes = dislikes
    }
    
    static func == (lhs: Joke, rhs: Joke) -> Bool {
        return lhs.id == rhs.id &&
               lhs.setup == rhs.setup &&
               lhs.punchlines == rhs.punchlines &&
               lhs.status == rhs.status &&
               lhs.authorId == rhs.authorId &&
               lhs.createdAt == rhs.createdAt &&
               lhs.views == rhs.views &&
               lhs.likes == rhs.likes &&
               lhs.dislikes == rhs.dislikes
    }
}
