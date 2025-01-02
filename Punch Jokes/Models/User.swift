import Foundation

class User: Identifiable, Codable, Equatable {
    var id: String = ""
    var email: String = ""
    var username: String?
    var name: String?
    var createdAt: Date = Date()
    var favouriteJokesIDs: [String]?
    
    init() {}
    
    init(id: String, email: String, username: String? = nil, name: String? = nil, createdAt: Date = Date(), favouriteJokesIDs: [String]? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.name = name
        self.createdAt = createdAt
        self.favouriteJokesIDs = favouriteJokesIDs
    }
    
    // Добавляем Equatable для сравнения объектов
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.username == rhs.username &&
               lhs.name == rhs.name &&
               lhs.createdAt == rhs.createdAt &&
               lhs.favouriteJokesIDs == rhs.favouriteJokesIDs
    }
}
