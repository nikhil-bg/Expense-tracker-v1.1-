import Foundation

/// Represents a single expense transaction
struct Expense: Identifiable, Codable {
    /// Unique identifier for the expense
    var id: UUID
    /// Amount in the original currency
    let amount: Double
    /// Category of the expense
    let category: Category
    /// Date when the expense occurred
    let date: Date
    /// Currency code (e.g., "USD", "EUR")
    let currency: String
    /// Optional note about the expense
    let note: String
    
    init(id: UUID = UUID(), amount: Double, category: Category, date: Date, currency: String, note: String) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.currency = currency
        self.note = note
    }
    
    /// Categories for classifying expenses
    enum Category: String, Codable, CaseIterable, Identifiable {
        // Essential
        case groceries = "Groceries"
        case dining = "Dining Out"
        case transport = "Transport"
        case utilities = "Utilities"
        case rent = "Rent/Mortgage"
        case healthcare = "Healthcare"
        
        // Lifestyle
        case entertainment = "Entertainment"
        case shopping = "Shopping"
        case travel = "Travel"
        case fitness = "Fitness"
        case education = "Education"
        case subscription = "Subscriptions"
        
        // Personal Care
        case clothing = "Clothing"
        case beauty = "Beauty & Care"
        case gifts = "Gifts"
        
        // Financial
        case insurance = "Insurance"
        case investment = "Investment"
        case savings = "Savings"
        case taxes = "Taxes"
        
        // Miscellaneous
        case pets = "Pets"
        case maintenance = "Maintenance"
        case other = "Other"
        
        var id: String { rawValue }
        
        // Group categories for better organization
        var group: CategoryGroup {
            switch self {
            case .groceries, .dining, .transport, .utilities, .rent, .healthcare:
                return .essential
            case .entertainment, .shopping, .travel, .fitness, .education, .subscription:
                return .lifestyle
            case .clothing, .beauty, .gifts:
                return .personalCare
            case .insurance, .investment, .savings, .taxes:
                return .financial
            case .pets, .maintenance, .other:
                return .miscellaneous
            }
        }
    }
    
    // Category groups for better organization
    enum CategoryGroup: String, CaseIterable {
        case essential = "Essential"
        case lifestyle = "Lifestyle"
        case personalCare = "Personal Care"
        case financial = "Financial"
        case miscellaneous = "Miscellaneous"
        
        var icon: String {
            switch self {
            case .essential: return "house.fill"
            case .lifestyle: return "star.fill"
            case .personalCare: return "heart.fill"
            case .financial: return "banknote.fill"
            case .miscellaneous: return "ellipsis.circle.fill"
            }
        }
    }
} 