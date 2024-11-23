import Foundation

struct BudgetSettings: Codable {
    var monthlyBudget: Double
    var currency: String
    
    static let `default` = BudgetSettings(monthlyBudget: 0, currency: "USD")
} 