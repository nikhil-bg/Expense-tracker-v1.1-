import SwiftUI
import Charts

// Daily Average Detail View
struct DailyAverageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    let timeFilter: TimeFilter
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Average Chart
                    Chart {
                        ForEach(last7DaysData, id: \.date) { data in
                            BarMark(
                                x: .value("Date", data.date, unit: .day),
                                y: .value("Amount", data.amount)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }
                    .frame(height: 200)
                    .padding()
                    
                    // Stats Summary
                    VStack(spacing: 16) {
                        StatRow(title: "7-Day Average", 
                               value: sevenDayAverage,
                               format: .currency)
                        StatRow(title: "30-Day Average", 
                               value: thirtyDayAverage,
                               format: .currency)
                        StatRow(title: "Highest Day", 
                               value: highestDayAmount,
                               format: .currency,
                               subtitle: highestDayDate)
                    }
                    .padding()
                }
            }
            .navigationTitle("Daily Average")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // Computed properties for the data
    private var last7DaysData: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!
        let dates = calendar.generateDates(
            inside: DateInterval(start: startDate, end: endDate),
            matching: DateComponents(hour: 0, minute: 0, second: 0)
        )
        
        return dates.map { date in
            let dayExpenses = expenseManager.expenses.filter {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            let total = dayExpenses.reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
            return (date: date, amount: total)
        }
    }
    
    private var sevenDayAverage: Double {
        let total = last7DaysData.reduce(0) { $0 + $1.amount }
        return total / Double(last7DaysData.count)
    }
    
    private var thirtyDayAverage: Double {
        // Calculate 30-day average similar to 7-day
        // Implementation details...
        return 0 // Placeholder
    }
    
    private var highestDayAmount: Double {
        last7DaysData.max(by: { $0.amount < $1.amount })?.amount ?? 0
    }
    
    private var highestDayDate: String {
        guard let highest = last7DaysData.max(by: { $0.amount < $1.amount }) else { return "" }
        return highest.date.formatted(date: .abbreviated, time: .omitted)
    }
}

// Break down MonthlyDetailView into smaller components
struct MonthlyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    let timeFilter: TimeFilter
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MonthlyProgressView(
                        monthlyTotal: monthlyTotal,
                        monthlyBudget: monthlyBudget
                    )
                    
                    CategoryBreakdownView(
                        categories: monthlyCategories
                    )
                }
            }
            .navigationTitle("This Month")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // Sample monthly budget - you might want to make this configurable
    private let monthlyBudget: Double = 2000
    
    private var monthlyTotal: Double {
        let calendar = Calendar.current
        let now = Date()
        return expenseManager.expenses
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
    }
    
    private var monthlyCategories: [(category: String, amount: Double)] {
        // Group expenses by category and calculate totals
        var categoryTotals: [String: Double] = [:]
        let calendar = Calendar.current
        let now = Date()
        
        for expense in expenseManager.expenses where calendar.isDate(expense.date, equalTo: now, toGranularity: .month) {
            let amount = expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            categoryTotals[expense.category.rawValue, default: 0] += amount
        }
        
        return categoryTotals.map { ($0.key, $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}

// Split into smaller view components
struct MonthlyProgressView: View {
    let monthlyTotal: Double
    let monthlyBudget: Double
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Monthly Budget")
                .font(.headline)
            ProgressView(value: monthlyTotal, total: monthlyBudget)
                .tint(monthlyTotal > monthlyBudget ? .red : .blue)
            HStack {
                Text(monthlyTotal, format: .currency(code: expenseManager.selectedCurrency))
                Spacer()
                Text(monthlyBudget, format: .currency(code: expenseManager.selectedCurrency))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct CategoryBreakdownView: View {
    let categories: [(category: String, amount: Double)]
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(categories, id: \.category) { data in
                HStack {
                    Text(data.category)
                    Spacer()
                    Text(data.amount, format: .currency(code: expenseManager.selectedCurrency))
                }
                .padding(.horizontal)
            }
        }
    }
}

// Categories Detail View
struct CategoriesDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    let selectedTimeFilter: TimeFilter
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Expense.CategoryGroup.allCases, id: \.self) { group in
                    if !categoriesInGroup(for: group).isEmpty {
                        CategoryGroupSection(group: group, timeFilter: selectedTimeFilter)
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // Helper function to check if a group has any active categories
    private func categoriesInGroup(for group: Expense.CategoryGroup) -> [Expense.Category] {
        Expense.Category.allCases
            .filter { $0.group == group }
            .filter { category in
                filteredExpenses.contains { $0.category == category }
            }
    }
    
    // Add filtered expenses property
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        
        return expenseManager.expenses.filter { expense in
            switch selectedTimeFilter {
            case .all:
                return true
            case .today:
                return calendar.isDateInToday(expense.date)
            case .week:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
            }
        }
    }
}

// Update CategoryGroupSection
struct CategoryGroupSection: View {
    let group: Expense.CategoryGroup
    let timeFilter: TimeFilter
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        Section(group.rawValue) {
            ForEach(activeCategories, id: \.self) { category in
                CategoryRow(category: category, timeFilter: timeFilter)
            }
        }
    }
    
    private var activeCategories: [Expense.Category] {
        let filteredExpenses = expenseManager.expenses.filter(matchesTimeFilter)
        return Expense.Category.allCases
            .filter { $0.group == group }
            .filter { category in
                filteredExpenses.contains { $0.category == category }
            }
    }
    
    private func matchesTimeFilter(_ expense: Expense) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeFilter {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(expense.date)
        case .week:
            return calendar.isDate(expense.date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
        case .year:
            return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
        }
    }
}

// Update CategoryRow
struct CategoryRow: View {
    let category: Expense.Category
    let timeFilter: TimeFilter
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(categoryColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: categoryIcon)
                        .foregroundStyle(.white)
                }
            
            Text(category.rawValue)
            
            Spacer()
            
            Text(amount, format: .currency(code: expenseManager.selectedCurrency))
                .foregroundStyle(.secondary)
        }
    }
    
    private var categoryColor: Color {
        switch category.group {
        case .essential: return .blue
        case .lifestyle: return .purple
        case .personalCare: return .pink
        case .financial: return .green
        case .miscellaneous: return .gray
        }
    }
    
    private var categoryIcon: String {
        switch category {
        case .groceries: return "cart.fill"
        case .dining: return "fork.knife"
        case .transport: return "car.fill"
        case .utilities: return "bolt.fill"
        case .rent: return "house.fill"
        case .healthcare: return "cross.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .travel: return "airplane"
        case .fitness: return "figure.run"
        case .education: return "book.fill"
        case .subscription: return "repeat.circle.fill"
        case .clothing: return "tshirt.fill"
        case .beauty: return "sparkles"
        case .gifts: return "gift.fill"
        case .insurance: return "shield.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .savings: return "banknote.fill"
        case .taxes: return "doc.text.fill"
        case .pets: return "pawprint.fill"
        case .maintenance: return "wrench.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
    
    private var amount: Double {
        expenseManager.expenses
            .filter(matchesTimeFilter)
            .filter { $0.category == category }
            .reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
    }
    
    private func matchesTimeFilter(_ expense: Expense) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeFilter {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(expense.date)
        case .week:
            return calendar.isDate(expense.date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
        case .year:
            return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
        }
    }
}

// Helper Views
struct StatRow: View {
    let title: String
    let value: Double
    let format: Format
    var subtitle: String? = nil
    
    enum Format {
        case currency
        case percentage
        case number
    }
    
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                switch format {
                case .currency:
                    Text(value, format: .currency(code: expenseManager.selectedCurrency))
                case .percentage:
                    Text("\(value, specifier: "%.1f")%")
                case .number:
                    Text("\(Int(value))")
                }
                
                if let subtitle = subtitle {
                    Text("(\(subtitle))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.headline)
        }
    }
} 