import Foundation
import SwiftUI

class ExpenseManager: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var selectedCurrency = "USD"
    let currencyManager: CurrencyManager
    
    @Published var budgetSettings: BudgetSettings {
        didSet {
            saveBudgetSettings()
        }
    }
    
    var isRatesReady: Bool {
        !currencyManager.exchangeRates.isEmpty
    }
    
    private var cachedRates: [String: Double] {
        get {
            if let data = UserDefaults.standard.data(forKey: "cachedExchangeRates"),
               let rates = try? JSONDecoder().decode([String: Double].self, from: data) {
                return rates
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "cachedExchangeRates")
            }
        }
    }
    
    static let availableCurrencies = [
        "USD", // US Dollar
        "EUR", // Euro
        "GBP", // British Pound
        "JPY", // Japanese Yen
        "AUD", // Australian Dollar
        "CAD", // Canadian Dollar
        "CHF", // Swiss Franc
        "CNY", // Chinese Yuan
        "HKD", // Hong Kong Dollar
        "NZD", // New Zealand Dollar
        "SGD", // Singapore Dollar
        "INR", // Indian Rupee
        "MXN", // Mexican Peso
        "BRL", // Brazilian Real
        "KRW", // South Korean Won
        "SEK"  // Swedish Krona
    ]
    
    private let userDefaults = UserDefaults.standard
    private let expensesKey = "savedExpenses"
    
    init() {
        self.currencyManager = CurrencyManager()
        self.budgetSettings = UserDefaults.standard.data(forKey: "budgetSettings")
            .flatMap { try? JSONDecoder().decode(BudgetSettings.self, from: $0) }
            ?? .default
        
        loadExpenses()
        
        if let data = UserDefaults.standard.data(forKey: "cachedExchangeRates"),
           let rates = try? JSONDecoder().decode([String: Double].self, from: data) {
            currencyManager.exchangeRates = rates
        }
        
        Task {
            await fetchLatestRates()
        }
    }
    
    private func fetchLatestRates() async {
        await currencyManager.fetchExchangeRatesAsync()
        if !currencyManager.exchangeRates.isEmpty {
            cachedRates = currencyManager.exchangeRates
        }
    }
    
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        saveExpenses()
    }
    
    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveExpenses()
    }
    
    func getConvertedAmount(_ expense: Expense, to targetCurrency: String) -> Double {
        guard expense.currency != targetCurrency else { return expense.amount }
        
        guard isRatesReady else { 
            if expense.currency == targetCurrency {
                return expense.amount
            }
            if expense.currency == "USD" {
                return expense.amount
            }
            return expense.amount
        }
        
        let baseRate = currencyManager.exchangeRates[expense.currency] ?? 1.0
        let targetRate = currencyManager.exchangeRates[targetCurrency] ?? 1.0
        
        return expense.amount * (targetRate / baseRate)
    }
    
    private func saveExpenses() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            userDefaults.set(encoded, forKey: expensesKey)
        }
    }
    
    private func loadExpenses() {
        if let data = userDefaults.data(forKey: expensesKey),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            expenses = decoded
        }
    }
    
    private func saveBudgetSettings() {
        if let encoded = try? JSONEncoder().encode(budgetSettings) {
            UserDefaults.standard.set(encoded, forKey: "budgetSettings")
        }
    }
    
    func setBudget(_ amount: Double, currency: String) {
        budgetSettings = BudgetSettings(monthlyBudget: amount, currency: currency)
    }
    
    func getRemainingBudget() -> Double {
        let convertedBudget = getConvertedAmount(
            amount: budgetSettings.monthlyBudget,
            from: budgetSettings.currency,
            to: selectedCurrency
        )
        return convertedBudget - getCurrentMonthTotal()
    }
    
    func getCurrentMonthTotal() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        
        return expenses
            .filter { $0.date >= monthStart && $0.date < monthEnd }
            .reduce(0) { sum, expense in
                sum + getConvertedAmount(expense, to: selectedCurrency)
            }
    }
    
    func getBudgetProgress() -> Double {
        let monthTotal = getCurrentMonthTotal()
        let convertedBudget = getConvertedAmount(
            amount: budgetSettings.monthlyBudget,
            from: budgetSettings.currency,
            to: selectedCurrency
        )
        guard convertedBudget > 0 else { return 0 }
        return min(monthTotal / convertedBudget, 1.0)
    }
    
    func getConvertedAmount(amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double {
        if sourceCurrency == targetCurrency {
            return amount
        }
        
        guard isRatesReady else {
            return amount
        }
        
        return currencyManager.convert(amount, from: sourceCurrency, to: targetCurrency) ?? amount
    }
    
    func getFinancialWellnessScore(for timeFrame: TimeFrame) -> Double {
        let calendar = Calendar.current
        let now = Date()
        var score: Double = 100
        
        // Get relevant expenses for the time period
        let relevantExpenses: [Expense]
        switch timeFrame {
        case .week:
            let weekStart = calendar.startOfWeek(for: now)
            relevantExpenses = expenses.filter { $0.date >= weekStart }
        case .month:
            relevantExpenses = expenses.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .threeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            relevantExpenses = expenses.filter { $0.date >= threeMonthsAgo }
        case .sixMonths:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            relevantExpenses = expenses.filter { $0.date >= sixMonthsAgo }
        case .year:
            relevantExpenses = expenses.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
        }
        
        // Calculate score based on various factors
        // ... rest of the implementation
        
        return max(0, min(100, score))
    }
    
    private func calculateMonthlyScore(spending: Double) -> Double {
        let budget = budgetSettings.monthlyBudget
        let spendingRatio = spending / budget
        
        // Much stricter score calculation:
        // 100: Spending <= 40% of budget (Excellent savings)
        // 90-99: Spending 41-60% of budget (Very good control)
        // 80-89: Spending 61-75% of budget (Good management)
        // 70-79: Spending 76-85% of budget (Careful monitoring needed)
        // 60-69: Spending 86-95% of budget (Getting close to limit)
        // 40-59: Spending 96-100% of budget (At budget limit)
        // 20-39: Spending 101-110% of budget (Over budget)
        // 10-19: Spending > 110% of budget (Significantly over budget)
        // 10: Spending > 120% of budget (Critical overspending)
        
        switch spendingRatio {
        case ...0.40:
            return 100
        case 0.41...0.60:
            return 90 + (0.60 - spendingRatio) / 0.19 * 9
        case 0.61...0.75:
            return 80 + (0.75 - spendingRatio) / 0.14 * 9
        case 0.76...0.85:
            return 70 + (0.85 - spendingRatio) / 0.09 * 9
        case 0.86...0.95:
            return 60 + (0.95 - spendingRatio) / 0.09 * 9
        case 0.96...1.00:
            return 40 + (1.00 - spendingRatio) / 0.04 * 19
        case 1.01...1.10:
            return 20 + (1.10 - spendingRatio) / 0.09 * 19
        case 1.11...1.20:
            return max(15, 20 - (spendingRatio - 1.10) * 50)
        default:
            return max(10, 15 - (spendingRatio - 1.20) * 100) // Very sharp decline above 120%
        }
    }
    
    func getWellnessDescription(score: Double) -> (title: String, description: String, color: Color) {
        switch score {
        case 90...100:
            return ("Excellent", "You're well under budget with significant savings!", .green)
        case 80..<90:
            return ("Very Good", "You're managing your budget effectively.", .green)
        case 70..<80:
            return ("Good", "You're within budget but approaching limits.", .blue)
        case 60..<70:
            return ("Warning", "You're getting close to your budget limit.", .yellow)
        case 40..<60:
            return ("Critical", "You've reached your budget limit. Reduce spending immediately.", .orange)
        case 20..<40:
            return ("Danger", "You're over budget. Immediate action required.", .red)
        default:
            return ("Severe", "Spending is critically high. Emergency measures needed.", .red)
        }
    }
}

// Update TimeFrame enum
enum TimeFrame: String {
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "Year"
} 