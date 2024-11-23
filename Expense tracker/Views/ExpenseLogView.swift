import SwiftUI
import Charts

struct ExpenseLogView: View {
    @EnvironmentObject private var expenseManager: ExpenseManager
    @State private var showingAddExpense = false
    @State private var selectedFilter: TimeFilter = .week
    @State private var searchText = ""
    @State private var selectedCategory: Expense.Category?
    @State private var showCategoryDetail = false
    @State private var showingDailyAverageDetail = false
    @State private var showingMonthlyDetail = false
    @State private var showingCategoriesDetail = false
    @State private var showingBudgetSettings = false
    @State private var isLoading = true
    
    let currencies = ExpenseManager.availableCurrencies
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && !expenseManager.isRatesReady {
                    loadingView
                } else {
                    mainContentView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addExpenseButton
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingDailyAverageDetail) {
                DailyAverageDetailView(timeFilter: selectedFilter)
            }
            .sheet(isPresented: $showingMonthlyDetail) {
                MonthlyDetailView(timeFilter: selectedFilter)
            }
            .sheet(isPresented: $showingCategoriesDetail) {
                CategoriesDetailView(selectedTimeFilter: selectedFilter)
            }
            .sheet(isPresented: $showingBudgetSettings) {
                BudgetSettingsView(expenseManager: expenseManager)
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading expenses...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            currencySelector
            Divider()
            timePeriodSelector
            Divider()
            mainScrollContent
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
    }
    
    private var currencySelector: some View {
        HStack {
            Menu {
                ForEach(currencies, id: \.self) { currency in
                    Button {
                        withAnimation {
                            expenseManager.selectedCurrency = currency
                        }
                    } label: {
                        HStack {
                            Text(currency)
                            if currency == expenseManager.selectedCurrency {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: currencySymbol(for: expenseManager.selectedCurrency))
                        .font(.title3)
                    Text(expenseManager.selectedCurrency)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            if expenseManager.currencyManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    expenseManager.currencyManager.fetchExchangeRates()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    private var timePeriodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
    
    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                
                Divider()
                    .background(Color(uiColor: .separator))
                
                categoryOverviewSection
                
                Divider()
                    .background(Color(uiColor: .separator))
                
                transactionSection
            }
            .padding(.vertical)
        }
    }
    
    private var addExpenseButton: some View {
        Button {
            showingAddExpense = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
    
    // Add missing sections
    private var summarySection: some View {
        VStack(spacing: 16) {
            // Only show Budget Progress Section for monthly or shorter time periods
            if expenseManager.budgetSettings.monthlyBudget > 0 && selectedFilter != .year {
                VStack(spacing: 8) {
                    HStack {
                        Text("Monthly Budget")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showingBudgetSettings = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    ProgressView(value: expenseManager.getBudgetProgress()) {
                        HStack {
                            Text(expenseManager.getRemainingBudget(), format: .currency(code: expenseManager.selectedCurrency))
                                .font(.headline)
                            Text("remaining")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(expenseManager.getBudgetProgress() * 100))%")
                                .font(.headline)
                        }
                    }
                    .tint(getBudgetProgressColor())
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else if selectedFilter != .year {
                // Show "Set Monthly Budget" button only when not in yearly view
                Button {
                    showingBudgetSettings = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Set Monthly Budget")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
                .padding()
            }
            
            // Total Amount Card
            VStack(spacing: 8) {
                Text("Total Spending")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(totalSpending, format: .currency(code: expenseManager.selectedCurrency))
                    .font(.system(size: 34, weight: .bold))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Quick Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickStatCard(
                    title: "Daily Avg",
                    value: dailyAverage,
                    icon: "chart.bar",
                    color: .blue,
                    isCount: false,
                    action: {},
                    periodTotal: totalSpending
                )
                .allowsHitTesting(false)
                
                QuickStatCard(
                    title: "This Month",
                    value: monthlyTotal,
                    icon: "calendar",
                    color: .purple,
                    isCount: false,
                    action: { 
                        selectedFilter = .month
                        showingMonthlyDetail = true 
                    },
                    periodTotal: totalSpending
                )
                .allowsHitTesting(false)
                
                QuickStatCard(
                    title: "Categories",
                    value: Double(activeCategories),
                    icon: "square.grid.2x2",
                    color: .orange,
                    isCount: true,
                    action: { showingCategoriesDetail = true },
                    periodTotal: totalSpending
                )
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
    
    private var categoryOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(categoryData.prefix(3)) { category in
                if let cat = Expense.Category(rawValue: category.name) {
                    NavigationLink(destination: CategoryDetailView(
                        category: cat,
                        expenses: filteredExpenses.filter { $0.category == cat },
                        parentTimeFilter: selectedFilter
                    )) {
                        CategoryRowView(category: category)
                    }
                }
            }
        }
    }
    
    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transactions")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                ForEach(Array(filteredExpenses.enumerated()), id: \.element.id) { index, expense in
                    VStack(spacing: 0) {
                        ExpenseRowView(expense: expense)
                            .padding(.horizontal)
                            .background(Color(uiColor: .systemBackground))
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // Show confirmation dialog before deleting
                                let amount = expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
                                let formattedAmount = amount.formatted(.currency(code: expenseManager.selectedCurrency))
                                
                                let alert = UIAlertController(
                                    title: "Delete Transaction",
                                    message: "Are you sure you want to delete this \(expense.category.rawValue) expense of \(formattedAmount)?",
                                    preferredStyle: .alert
                                )
                                
                                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                                    withAnimation {
                                        expenseManager.deleteExpense(expense)
                                    }
                                })
                                
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let viewController = windowScene.windows.first?.rootViewController {
                                    viewController.present(alert, animated: true)
                                }
                            }
                        
                        if index < filteredExpenses.count - 1 {
                            Divider()
                                .padding(.leading, 76)
                                .background(Color(uiColor: .separator))
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(uiColor: .separator), lineWidth: 0.5)
            )
        }
        .padding(.horizontal)
    }
    
    // Add computed properties
    private var totalSpending: Double {
        filteredExpenses.reduce(0) { sum, expense in
            sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
    }
    
    private var dailyAverage: Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate total days in selected period
        let daysInPeriod: Double = {
            switch selectedFilter {
            case .all:
                // For all time, use actual date range
                if let earliest = filteredExpenses.map({ $0.date }).min() {
                    return max(1, Double(calendar.dateComponents([.day], from: earliest, to: now).day ?? 1))
                }
                return 1
            case .today:
                return 1
            case .week:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let days = calendar.dateComponents([.day], from: weekStart, to: now).day ?? 1
                return max(1, Double(days + 1))
            case .month:
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let days = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1
                return max(1, Double(days + 1))
            case .year:
                let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
                let days = calendar.dateComponents([.day], from: yearStart, to: now).day ?? 1
                return max(1, Double(days + 1))
            }
        }()
        
        return totalSpending / daysInPeriod
    }
    
    private var monthlyTotal: Double {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        
        return expenseManager.expenses
            .filter { expense in
                expense.date >= monthStart && expense.date < monthEnd
            }
            .reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
    }
    
    private var activeCategories: Int {
        Set(filteredExpenses.map(\.category)).count
    }
    
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        
        return expenseManager.expenses.filter { expense in
            switch selectedFilter {
            case .all:
                return true
            case .today:
                return calendar.isDateInToday(expense.date)
            case .week:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
                return expense.date >= weekStart && expense.date < weekEnd
            case .month:
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                return expense.date >= monthStart && expense.date < monthEnd
            case .year:
                let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
                let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
                return expense.date >= yearStart && expense.date < yearEnd
            }
        }
    }
    
    private func currencySymbol(for currency: String) -> String {
        switch currency {
        case "USD": return "dollarsign.circle.fill"
        case "EUR": return "eurosign.circle.fill"
        case "GBP": return "sterlingsign.circle.fill"
        case "JPY": return "yensign.circle.fill"
        case "INR": return "indianrupeesign.circle.fill"
        case "CNY": return "yensign.circle.fill"
        case "KRW": return "wonsign.circle.fill"
        case "SEK": return "swedishkronasign.circle.fill"
        default: return "dollarsign.circle.fill"
        }
    }
    
    private var categoryData: [CategoryData] {
        var categoryAmounts: [String: Double] = [:]
        
        for expense in filteredExpenses {
            let amount = expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            categoryAmounts[expense.category.rawValue, default: 0] += amount
        }
        
        return categoryAmounts.map { CategoryData(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
    // Add color helper for budget progress
    private func getBudgetProgressColor() -> Color {
        let progress = expenseManager.getBudgetProgress()
        switch progress {
        case 0..<0.7: return .green
        case 0.7..<0.9: return .yellow
        default: return .red
        }
    }
}

// Add CategoryDetailView
struct CategoryDetailView: View {
    let category: Expense.Category
    let expenses: [Expense]
    let parentTimeFilter: TimeFilter
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    @State private var selectedTimeFrame: TimeFilter
    
    init(category: Expense.Category, expenses: [Expense], parentTimeFilter: TimeFilter) {
        self.category = category
        self.expenses = expenses
        self.parentTimeFilter = parentTimeFilter
        _selectedTimeFrame = State(initialValue: parentTimeFilter)
    }
    
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        
        return expenses.filter { expense in
            switch selectedTimeFrame {
            case .all: return true
            case .today: return calendar.isDateInToday(expense.date)
            case .week: return calendar.isDate(expense.date, equalTo: now, toGranularity: .weekOfYear)
            case .month: return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            case .year: return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
            }
        }
        .sorted { $0.date > $1.date }
    }
    
    private func categoryColor(for category: Expense.Category) -> Color {
        switch category {
        case .groceries, .dining, .utilities, .rent, .healthcare:
            return .blue.opacity(0.8)
        case .entertainment, .shopping, .travel, .fitness:
            return .purple.opacity(0.8)
        case .clothing, .beauty:
            return .pink.opacity(0.8)
        case .investment, .insurance, .taxes, .savings:
            return .green.opacity(0.8)
        case .education, .subscription, .gifts, .pets, .maintenance, .transport, .other:
            return .orange.opacity(0.8)
        }
    }
    
    private func categoryIcon(for category: Expense.Category) -> String {
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
    
    // Define Insight struct
    struct Insight {
        let title: String
        let description: String
        let icon: String
        let color: Color
    }
    
    private var totalAmount: Double {
        filteredExpenses.reduce(0) { sum, expense in
            sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
    }
    
    private var averageAmount: Double {
        guard !filteredExpenses.isEmpty else { return 0 }
        return totalAmount / Double(filteredExpenses.count)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Period Selector - Simplified version
                    Picker("Time Frame", selection: $selectedTimeFrame) {
                        ForEach(TimeFilter.allCases, id: \.self) { period in
                            Text(timeFrameLabel(for: period))
                                .tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Summary Card
                    VStack(spacing: 16) {
                        // Category Icon
                        Circle()
                            .fill(categoryColor(for: category))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: categoryIcon(for: category))
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        
                        // Stats Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatCard(
                                title: "Total",
                                value: totalAmount,
                                format: .currency
                            )
                            
                            StatCard(
                                title: "Average",
                                value: averageAmount,
                                format: .currency
                            )
                            
                            StatCard(
                                title: "Count",
                                value: Double(filteredExpenses.count),
                                format: .number
                            )
                        }
                        
                        // Percentage of Total
                        if let percentageOfTotal = calculatePercentageOfTotal() {
                            HStack {
                                Text("of total spending")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text(String(format: "%.1f%%", percentageOfTotal))
                                    .font(.title3.bold())
                                    .foregroundStyle(categoryColor(for: category))
                            }
                        }
                    }
                    .padding()
                    .background(categoryColor(for: category).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    // Insights Section
                    if let insights = generateInsights() {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Insights")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(insights, id: \.title) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                    }
                    
                    // Recent Transactions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Transactions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(filteredExpenses) { expense in
                            ExpenseRowView(expense: expense)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(category.rawValue)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private func calculatePercentageOfTotal() -> Double? {
        let allExpensesTotal = expenseManager.expenses
            .filter { expense in
                switch selectedTimeFrame {
                case .all: return true
                case .today: return Calendar.current.isDateInToday(expense.date)
                case .week: return Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .weekOfYear)
                case .month: return Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .month)
                case .year: return Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .year)
                }
            }
            .reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        
        guard allExpensesTotal > 0 else { return nil }
        return (totalAmount / allExpensesTotal) * 100
    }
    
    private func generateInsights() -> [Insight]? {
        guard !filteredExpenses.isEmpty else { return nil }
        
        var insights: [Insight] = []
        
        // Frequency Analysis
        let daysInPeriod = calculateDaysInPeriod()
        if daysInPeriod > 0 {
            let frequency = Double(filteredExpenses.count) / daysInPeriod
            insights.append(Insight(
                title: "Spending Frequency",
                description: String(format: "You spend on \(category.rawValue.lowercased()) about %.1f times per week", frequency * 7),
                icon: "calendar",
                color: .blue
            ))
        }
        
        // Amount Pattern
        if let highestAmount = filteredExpenses.max(by: { a, b in
            expenseManager.getConvertedAmount(a, to: expenseManager.selectedCurrency) <
            expenseManager.getConvertedAmount(b, to: expenseManager.selectedCurrency)
        }) {
            let amount = expenseManager.getConvertedAmount(highestAmount, to: expenseManager.selectedCurrency)
            insights.append(Insight(
                title: "Highest Expense",
                description: "Your highest \(category.rawValue.lowercased()) expense was \(amount.formatted(.currency(code: expenseManager.selectedCurrency))) on \(highestAmount.date.formatted(date: .long, time: .omitted))",
                icon: "arrow.up.right",
                color: .orange
            ))
        }
        
        // Time Pattern
        let timePattern = analyzeTimePattern()
        if let commonTime = timePattern.max(by: { $0.value < $1.value })?.key {
            insights.append(Insight(
                title: "Time Pattern",
                description: "You tend to spend more on \(category.rawValue.lowercased()) during \(commonTime)",
                icon: "clock",
                color: .purple
            ))
        }
        
        return insights
    }
    
    private func calculateDaysInPeriod() -> Double {
        switch selectedTimeFrame {
        case .all: return 30 // Default to monthly view
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
    
    private func analyzeTimePattern() -> [String: Int] {
        var patterns: [String: Int] = [
            "morning": 0,
            "afternoon": 0,
            "evening": 0
        ]
        
        for expense in filteredExpenses {
            let hour = Calendar.current.component(.hour, from: expense.date)
            switch hour {
            case 5..<12: patterns["morning"]? += 1
            case 12..<17: patterns["afternoon"]? += 1
            default: patterns["evening"]? += 1
            }
        }
        
        return patterns
    }
    
    // Add helper function for concise time frame labels
    private func timeFrameLabel(for timeFrame: TimeFilter) -> String {
        switch timeFrame {
        case .all: return "All"
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// Supporting Views
struct StatCard: View {
    let title: String
    let value: Double
    let format: Format
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    enum Format {
        case currency
        case number
        case percentage
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Group {
                switch format {
                case .currency:
                    Text(value, format: .currency(code: expenseManager.selectedCurrency))
                case .number:
                    Text("\(Int(value))")
                case .percentage:
                    Text("\(Int(value))%")
                }
            }
            .font(.headline)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InsightCard: View {
    let insight: CategoryDetailView.Insight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundStyle(insight.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .bold()
                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(insight.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct QuickStatCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    let isCount: Bool
    let action: () -> Void
    let periodTotal: Double
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                
                Group {
                    if isCount {
                        Text("\(max(0, Int(value.isFinite ? value : 0)))")
                            .font(.title3.bold())
                    } else {
                        Text(value, format: .currency(code: expenseManager.selectedCurrency))
                            .font(.title3.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .frame(height: 28)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// Add CategoryRowView
struct CategoryRowView: View {
    let category: CategoryData
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(categoryColor(for: category.name))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: categoryIcon(for: category.name))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                Text(category.amount, format: .currency(code: expenseManager.selectedCurrency))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
    
    private func categoryColor(for name: String) -> Color {
        guard let category = Expense.Category(rawValue: name) else { return .secondary }
        switch category {
        case .groceries, .dining, .utilities, .rent, .healthcare:
            return .blue.opacity(0.8)
        case .entertainment, .shopping, .travel, .fitness:
            return .purple.opacity(0.8)
        case .clothing, .beauty:
            return .pink.opacity(0.8)
        case .investment, .insurance, .taxes, .savings:
            return .green.opacity(0.8)
        case .education, .subscription, .gifts, .pets, .maintenance, .transport, .other:
            return .orange.opacity(0.8)
        }
    }
    
    private func categoryIcon(for name: String) -> String {
        guard let category = Expense.Category(rawValue: name) else { return "square.grid.2x2.fill" }
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
}

// Add CategoryData struct
struct CategoryData: Identifiable {
    let name: String
    let amount: Double
    var id: String { name }
}

// Update BudgetSettingsView
struct BudgetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    @State private var budgetAmount = ""  // Changed to empty string initially
    
    init(expenseManager: ExpenseManager) {
        // Don't set initial value anymore, let it be empty
        _budgetAmount = State(initialValue: "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Budget") {
                    HStack {
                        TextField("0", text: $budgetAmount)
                            .keyboardType(.decimalPad)
                            .onChange(of: budgetAmount) { oldValue, newValue in
                                // Filter out any non-numeric characters except decimal point
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                // Ensure only one decimal point
                                if filtered.components(separatedBy: ".").count > 2 {
                                    budgetAmount = oldValue
                                } else {
                                    budgetAmount = filtered
                                }
                            }
                        Text(expenseManager.selectedCurrency)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Budget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = Double(budgetAmount) {
                            expenseManager.setBudget(amount, currency: expenseManager.selectedCurrency)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                // If there's an existing budget, show it
                if expenseManager.budgetSettings.monthlyBudget > 0 {
                    budgetAmount = String(format: "%.2f", expenseManager.budgetSettings.monthlyBudget)
                }
            }
        }
    }
}

// ... rest of the code remains the same ...