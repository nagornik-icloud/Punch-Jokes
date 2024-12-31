import Foundation

enum Tab: String, CaseIterable {
    case home = "house"
    case favorites = "heart"
    case add = "plus"
    case profile = "person"
    
    var title: String {
        switch self {
        case .home:
            return "Все шутки"
        case .favorites:
            return "Избранное"
        case .add:
            return "Добавить"
        case .profile:
            return "Профиль"
        }
    }
}
