import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject private var expenseManager: ExpenseManager
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var showingCategoryDetail = false
    @State private var selectedCategory: Expense.Category?
    @State private var selectedQuickStat: QuickStatType?
    @State private var isLoading = true
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "Year"
    }
    
    enum QuickStatType: String, Identifiable {
        case essential = "Essential"
        case discretionary = "Discretionary"
        case largeExpenses = "Large Expenses"
        
        var id: String { rawValue }
    }
    
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        
        return expenseManager.expenses.filter { expense in
            switch selectedTimeFrame {
            case .week:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return expense.date >= weekStart
            case .month:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            case .threeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                return expense.date >= threeMonthsAgo
            case .sixMonths:
                let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
                return expense.date >= sixMonthsAgo
            case .year:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var totalSpendingInSelectedCurrency: Double {
        filteredExpenses.reduce(0) { total, expense in
            total + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
    }
    
    private var spendingChangePercentage: Double {
        let previousTotal = previousPeriodSpending
        guard previousTotal > 0 else { return 0 }
        
        // Adjust calculation based on time frame
        let change = ((totalSpendingInSelectedCurrency - previousTotal) / previousTotal) * 100
        
        // Normalize the percentage for different time frames
        switch selectedTimeFrame {
        case .week:
            return change // Weekly change
        case .month:
            return change
        case .threeMonths:
            return change / 3
        case .sixMonths:
            return change / 6
        case .year:
            return change / 12
        }
    }
    
    private var previousPeriodSpending: Double {
        let calendar = Calendar.current
        let now = Date()
        let previousStart: Date
        let previousEnd: Date
        
        switch selectedTimeFrame {
        case .week:
            previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: calendar.startOfWeek(for: now)) ?? now
            previousEnd = calendar.date(byAdding: .day, value: -1, to: calendar.startOfWeek(for: now)) ?? now
        case .month:
            previousStart = calendar.date(byAdding: .month, value: -1, to: calendar.startOfMonth(for: now)) ?? now
            previousEnd = calendar.date(byAdding: .day, value: -1, to: calendar.startOfMonth(for: now)) ?? now
        case .threeMonths:
            previousStart = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            previousEnd = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .sixMonths:
            previousStart = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            previousEnd = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .year:
            previousStart = calendar.date(byAdding: .year, value: -2, to: calendar.startOfYear(for: now)) ?? now
            previousEnd = calendar.date(byAdding: .year, value: -1, to: calendar.startOfYear(for: now)) ?? now
        }
        
        return expenseManager.expenses
            .filter { $0.date >= previousStart && $0.date <= previousEnd }
            .reduce(0) { total, expense in
                total + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
    }
    
    private var dailyAverage: Double {
        let numberOfDays: Double
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeFrame {
        case .week:
            // Get days since start of week
            let weekStart = calendar.startOfWeek(for: now)
            numberOfDays = Double(calendar.dateComponents([.day], from: weekStart, to: now).day ?? 7) + 1
        case .month:
            // Get actual days in current month
            let range = calendar.range(of: .day, in: .month, for: now)
            numberOfDays = Double(range?.count ?? 30)
        case .threeMonths:
            // Calculate actual days in last 3 months
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            numberOfDays = Double(calendar.dateComponents([.day], from: threeMonthsAgo, to: now).day ?? 90)
        case .sixMonths:
            // Calculate actual days in last 6 months
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            numberOfDays = Double(calendar.dateComponents([.day], from: sixMonthsAgo, to: now).day ?? 180)
        case .year:
            // Check if it's a leap year
            numberOfDays = calendar.isDate(now, equalTo: now, toGranularity: .year) ? 366 : 365
        }
        
        return totalSpendingInSelectedCurrency / max(numberOfDays, 1)
    }
    
    private struct CategoryData: Identifiable {
        let name: String
        let amount: Double
        var id: String { name }
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
    
    private struct WeekdaySpending: Identifiable {
        let weekday: String
        let average: Double
        var id: String { weekday }
    }
    
    private var weekdaySpending: [WeekdaySpending] {
        let calendar = Calendar.current
        let weekdays = calendar.weekdaySymbols
        
        var totals: [Int: (total: Double, count: Int)] = [:]
        
        for expense in filteredExpenses {
            let weekday = calendar.component(.weekday, from: expense.date)
            let amount = expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            let current = totals[weekday] ?? (0, 0)
            totals[weekday] = (current.total + amount, current.count + 1)
        }
        
        return weekdays.enumerated().map { index, name in
            let stats = totals[index + 1] ?? (0, 1)
            return WeekdaySpending(
                weekday: name,
                average: stats.total / Double(stats.count)
            )
        }
    }
    
    private var shouldShowLoadingState: Bool {
        isLoading && expenseManager.currencyManager.isLoading && !expenseManager.isRatesReady
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if shouldShowLoadingState {
                    ProgressView("Loading insights...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemGroupedBackground))
                } else {
                    VStack(spacing: 0) {
                        // Time Period Selector - Fixed at top
                        Picker("Time Frame", selection: $selectedTimeFrame) {
                            ForEach(TimeFrame.allCases, id: \.self) { period in
                                Text(period.rawValue)
                                    .tag(period)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .systemBackground))
                        
                        Divider()
                        
                        // Scrollable Content
                        ScrollView {
                            VStack(spacing: 24) {
                                spendingHealthCard
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                                    )
                                
                                Divider()
                                    .background(Color(uiColor: .separator))
                                
                                spendingPatternsCard
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                                    )
                                
                                Divider()
                                    .background(Color(uiColor: .separator))
                                
                                smartRecommendationsCard
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                                    )
                            }
                            .padding(.vertical)
                        }
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .navigationTitle("Spending Insights")
                    .sheet(item: $selectedQuickStat) { statType in
                        QuickStatDetailView(type: statType, timeFrame: selectedTimeFrame)
                    }
                }
            }
            .onChange(of: expenseManager.isRatesReady) { oldValue, newValue in
                if newValue {
                    // Refresh the view when rates are ready
                    isLoading = false
                }
            }
            .onAppear {
                // Check if rates are already ready
                if expenseManager.isRatesReady {
                    isLoading = false
                } else {
                    // Set a maximum wait time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoading = false
                    }
                }
            }
        }
    }
    
    private var spendingHealthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Financial Wellness")
                    .font(.headline)
                
                // Score and Status Section
                HStack(alignment: .center, spacing: 32) {
                    // Score Dial
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                                .frame(width: 120, height: 120)
                            
                            if expenseManager.isRatesReady {
                                Circle()
                                    .trim(from: 0, to: calculateSpendingHealthScore()/100)
                                    .stroke(
                                        scoreColor.gradient,
                                        style: StrokeStyle(
                                            lineWidth: 16,
                                            lineCap: .round
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                            }
                            
                            VStack(spacing: 4) {
                                if expenseManager.isRatesReady {
                                    Text("\(Int(calculateSpendingHealthScore()))")
                                        .font(.system(size: 36, weight: .bold))
                                    Text("Score")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                    }
                    
                    // Status and Description
                    let wellness = getWellnessDescription(score: calculateSpendingHealthScore())
                    VStack(alignment: .leading, spacing: 16) {
                        // Status Badge
                        HStack(spacing: 8) {
                            Image(systemName: getWellnessIcon(score: calculateSpendingHealthScore()))
                                .font(.headline)
                            Text(wellness.title)
                                .font(.headline)
                        }
                        .foregroundStyle(wellness.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(wellness.color.opacity(0.1))
                        .clipShape(Capsule())
                        
                        // Description
                        Text(wellness.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Key Metrics Section - Redesigned
                VStack(spacing: 12) {  // Reduced spacing
                    Text("Key Metrics")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {  // Reduced spacing
                        // Monthly/Weekly Change
                        CompactMetricCard(
                            title: selectedTimeFrame == .week ? "Week" : "Change",
                            value: selectedTimeFrame == .week ? calculateWeeklyChange() : spendingChangePercentage,
                            format: "%.1f%%",
                            icon: (selectedTimeFrame == .week ? calculateWeeklyChange() : spendingChangePercentage) > 0 
                                ? "arrow.up.right.circle.fill" 
                                : "arrow.down.right.circle.fill",
                            color: (selectedTimeFrame == .week ? calculateWeeklyChange() : spendingChangePercentage) <= 0 
                                ? Color.green 
                                : Color.red,
                            isLoading: !expenseManager.isRatesReady
                        )
                        
                        // Daily Average
                        CompactMetricCard(
                            title: "Daily",
                            value: dailyAverage,
                            format: "",
                            icon: "chart.bar.fill",
                            color: Color.blue,
                            isLoading: !expenseManager.isRatesReady
                        )
                        
                        // Savings Potential with improved layout
                        CompactMetricCard(
                            title: "Savings",
                            value: calculateSavingsPotential(),
                            format: "",
                            icon: "leaf.circle.fill",
                            color: Color.green,
                            isLoading: !expenseManager.isRatesReady
                        )
                    }
                }
            }
            .padding(20)
            .background(Color(uiColor: .systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(uiColor: .label).opacity(0.1), radius: 10)
        .padding(.horizontal)
    }
    
    // Add new CompactMetricCard for more compact design
    private struct CompactMetricCard: View {
        let title: String
        let value: Double
        let format: String
        let icon: String
        let color: Color
        let isLoading: Bool
        @EnvironmentObject private var expenseManager: ExpenseManager
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                // Title and Icon
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    // Value with improved formatting
                    if format.contains("%") {
                        Text(String(format: format, value))
                            .font(.callout.bold())
                        .foregroundStyle(color)
                    } else {
                        // Currency formatting with better scaling
                        Text(value, format: .currency(code: expenseManager.selectedCurrency))
                            .font(.callout.bold())
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)  // Reduced horizontal padding
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var spendingPatternsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Patterns")
                .font(.headline)
            
            // Change from spendingInsights to identifyPatterns()
            VStack(spacing: 12) {
                ForEach(identifyPatterns()) { pattern in
                    HStack(spacing: 16) {
                        Image(systemName: pattern.icon)
                            .font(.title2)
                            .foregroundStyle(pattern.color)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pattern.title)
                                .font(.subheadline)
                                .bold()
                            Text(pattern.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(pattern.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(uiColor: .label).opacity(0.1), radius: 10)
        .padding(.horizontal)
    }
    
    private var smartRecommendationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Recommendations")
                .font(.headline)
            
            VStack(spacing: 16) {
                ForEach(generateRecommendations(), id: \.title) { recommendation in
                    VStack(alignment: .leading, spacing: 12) {
                        // Header with icon and title
                        HStack {
                            Image(systemName: recommendation.icon)
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                                .padding(8)
                                .background(recommendation.color)
                                .clipShape(Circle())
                            
                            Text(recommendation.title)
                                .font(.subheadline)
                                .bold()
                        }
                        
                        // Description
                        Text(recommendation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Potential Savings
                        if let saving = recommendation.potentialSaving {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(.green)
                                Text("Potential saving: ")
                                    .font(.caption)
                                Text(saving, format: .currency(code: expenseManager.selectedCurrency))
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(recommendation.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(uiColor: .label).opacity(0.1), radius: 10)
        .padding(.horizontal)
    }
    
    // Helper Methods and Structures
    private struct HealthFactor {
        let title: String
        let icon: String
        let impact: String
        let color: Color
    }
    
    private struct SpendingPattern: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
        let color: Color
    }
    
    private struct Recommendation {
        let title: String
        let description: String
        let icon: String
        let color: Color
        let potentialSaving: Double?
    }
    
    private struct CategoryAnalysis {
        let category: Expense.Category
        let amount: Double
        let trend: String
        let changePercentage: Double
        let percentage: Double
        
        var changeIcon: String {
            changePercentage > 0 ? "arrow.up.right" : "arrow.down.right"
        }
    }
    
    private func calculateSpendingHealthScore() -> Double {
        let calendar = Calendar.current
        let now = Date()
        var score: Double = 100 // Start with perfect score
        
        // Get relevant expenses for the selected time frame
        let relevantExpenses = filteredExpenses
        
        // Get total spending for the period
        let totalSpending = relevantExpenses.reduce(0) { total, expense in
            total + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
        
        // Calculate average monthly spending for the period
        let monthsInPeriod: Double = {
            switch selectedTimeFrame {
            case .week: return 0.25 // Quarter of a month
            case .month: return 1
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .year: return 12
            }
        }()
        
        let monthlyAverage = totalSpending / monthsInPeriod
        
        // Calculate budget for the selected period
        let periodBudget = expenseManager.budgetSettings.monthlyBudget * monthsInPeriod
        
        // Convert budget to selected currency
        let convertedBudget = expenseManager.getConvertedAmount(
            amount: periodBudget,
            from: expenseManager.budgetSettings.currency,
            to: expenseManager.selectedCurrency
        )
        
        // Calculate spending ratio (actual spending / budget)
        let spendingRatio = convertedBudget > 0 ? totalSpending / convertedBudget : 1.0
        
        // Deduct points based on spending ratio
        score = calculateBaseScore(spendingRatio: spendingRatio)
        
        // Calculate spending trend
        let trendPenalty = calculateTrendPenalty(for: selectedTimeFrame)
        score -= trendPenalty
        
        // Additional factors that affect the score
        let essentialRatio = essentialSpendingPercentage / 100
        let discretionaryRatio = discretionarySpendingPercentage / 100
        
        // Adjust score based on essential vs discretionary spending
        if essentialRatio > 0.7 {
            // High essential spending indicates financial strain
            let penalty = min(20, (essentialRatio - 0.7) * 100)
            score -= penalty * getTimePeriodMultiplier()
        }
        
        // Adjust for spending consistency
        let consistency = calculateSpendingConsistency()
        if consistency < 0.5 {
            let penalty = min(10, (0.5 - consistency) * 50)
            score -= penalty * getTimePeriodMultiplier()
        }
        
        // Time frame specific adjustments
        switch selectedTimeFrame {
        case .week:
            // More volatile, so be more lenient
            score += 5
        case .month:
            // Standard baseline
            break
        case .threeMonths:
            // Check for month-over-month improvement
            if let trend = calculateMonthlyTrend(months: 3) {
                score += trend * 5 // Bonus for improvement trend
            }
        case .sixMonths:
            // Check for consistent improvement
            if let trend = calculateMonthlyTrend(months: 6) {
                score += trend * 8 // Higher bonus for sustained improvement
            }
        case .year:
            // Check for long-term financial management
            if let trend = calculateMonthlyTrend(months: 12) {
                score += trend * 10 // Highest bonus for year-long improvement
            }
        }
        
        // Ensure score stays within 10-100 range
        return max(10, min(100, score))
    }
    
    private func calculateBaseScore(spendingRatio: Double) -> Double {
        switch spendingRatio {
        case 0.0...0.85:
            // Excellent range: 90-100
            return 90 + ((0.85 - spendingRatio) / 0.85 * 10)
        case 0.86...0.95:
            // Very good range: 80-89
            return 80 + (0.95 - spendingRatio) / 0.09 * 9
        case 0.96...1.00:
            // Good range: 70-79
            return 70 + (1.00 - spendingRatio) / 0.04 * 9
        case 1.01...1.10:
            // Warning range: 50-69
            return 50 + (1.10 - spendingRatio) / 0.09 * 19
        case 1.11...1.20:
            // Critical range: 30-49
            return 30 + (1.20 - spendingRatio) / 0.09 * 19
        case 1.21...1.50:
            // Danger range: 15-29
            return max(15, 30 - (spendingRatio - 1.20) * 50)
        default:
            // Severe range: 10-14
            return max(10, 15 - (spendingRatio - 1.50) * 100)
        }
    }
    
    // Add helper method for spending consistency
    private func calculateSpendingConsistency() -> Double {
        let expenses = filteredExpenses
        guard !expenses.isEmpty else { return 1.0 }
        
        let dailyTotals = Dictionary(grouping: expenses) { expense in
            Calendar.current.startOfDay(for: expense.date)
        }.mapValues { dayExpenses in
            dayExpenses.reduce(0) { total, expense in
                total + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        }
        
        let values = Array(dailyTotals.values)
        guard !values.isEmpty else { return 1.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { sum, value in
            let diff = value - mean
            return sum + (diff * diff)
        } / Double(values.count)
        
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = standardDeviation / mean
        
        // Convert to a 0-1 scale where 1 is most consistent
        return max(0, min(1, 1 - (coefficientOfVariation / 2)))
    }
    
    private func identifyPatterns() -> [SpendingPattern] {
        var patterns: [SpendingPattern] = []
        
        // Highest Single Expense Pattern
        if let highestExpense = filteredExpenses.max(by: { 
            expenseManager.getConvertedAmount($0, to: expenseManager.selectedCurrency) <
            expenseManager.getConvertedAmount($1, to: expenseManager.selectedCurrency)
        }) {
            let amount = expenseManager.getConvertedAmount(highestExpense, to: expenseManager.selectedCurrency)
            patterns.append(SpendingPattern(
                title: "Largest Transaction",
                description: "Your highest expense was \(amount.formatted(.currency(code: expenseManager.selectedCurrency))) for \(highestExpense.category.rawValue) on \(highestExpense.date.formatted(date: .abbreviated, time: .omitted))",
                icon: "arrow.up.circle",
                color: .red
            ))
        }
        
        // Time of Day Distribution
        let timeDistribution = filteredExpenses.reduce(into: [String: Int]()) { result, expense in
            let hour = Calendar.current.component(.hour, from: expense.date)
            switch hour {
            case 5..<12: result["Morning (5AM-12PM)", default: 0] += 1
            case 12..<17: result["Afternoon (12PM-5PM)", default: 0] += 1
            case 17..<22: result["Evening (5PM-10PM)", default: 0] += 1
            default: result["Night (10PM-5AM)", default: 0] += 1
            }
        }
        
        if let peakTime = timeDistribution.max(by: { $0.value < $1.value }) {
            patterns.append(SpendingPattern(
                title: "Peak Spending Time",
                description: "You make most of your purchases during \(peakTime.key) (\(peakTime.value) transactions)",
                icon: "clock",
                color: .blue
            ))
        }
        
        // Frequency Pattern
        let daysWithExpenses = Set(filteredExpenses.map { 
            Calendar.current.startOfDay(for: $0.date)
        }).count
        let totalDays = calculateDaysInPeriod()
        let frequency = (Double(daysWithExpenses) / totalDays) * 100
        
        patterns.append(SpendingPattern(
            title: "Spending Frequency",
            description: "You make purchases on \(Int(frequency))% of days, averaging \(String(format: "%.1f", Double(filteredExpenses.count) / totalDays)) transactions per day",
            icon: "calendar.badge.clock",
            color: .indigo
        ))
        
        // Category Combination Pattern
        let commonPairs = findCommonCategoryCombinations()
        if let topPair = commonPairs.first {
            patterns.append(SpendingPattern(
                title: "Common Combinations",
                description: "You often combine \(topPair.0.rawValue) with \(topPair.1.rawValue) purchases on the same day",
                icon: "arrow.triangle.branch",
                color: .green
            ))
        }
        
        // Average Transaction Size
        let averageTransaction = totalSpendingInSelectedCurrency / Double(filteredExpenses.count)
        patterns.append(SpendingPattern(
            title: "Transaction Size",
            description: "Your average transaction is \(averageTransaction.formatted(.currency(code: expenseManager.selectedCurrency)))",
            icon: "creditcard",
            color: .orange
        ))
        
        // Weekly Pattern
        if let highestDay = weekdaySpending.max(by: { $0.average < $1.average }) {
            patterns.append(SpendingPattern(
                title: "Weekly Peak",
                description: "Your spending tends to peak on \(highestDay.weekday)s. Consider planning ahead for these days.",
                icon: "calendar",
                color: .purple
            ))
        }
        
        return patterns
    }
    
    // Helper function to find common category combinations
    private func findCommonCategoryCombinations() -> [(Expense.Category, Expense.Category)] {
        let calendar = Calendar.current
        var combinations: [String: Int] = [:]
        
        // Group expenses by date
        let expensesByDate = Dictionary(grouping: filteredExpenses) {
            calendar.startOfDay(for: $0.date)
        }
        
        // Find categories that appear together
        for (_, dayExpenses) in expensesByDate {
            let categories = Set(dayExpenses.map { $0.category })
            if categories.count >= 2 {
                for cat1 in categories {
                    for cat2 in categories where cat1 != cat2 {
                        let key = [cat1.rawValue, cat2.rawValue].sorted().joined(separator: "-")
                        combinations[key, default: 0] += 1
                    }
                }
            }
        }
        
        // Convert back to category pairs and sort by frequency
        return combinations
            .map { key, count -> (Expense.Category, Expense.Category, Int) in
                let cats = key.split(separator: "-").map(String.init)
                return (
                    Expense.Category(rawValue: cats[0]) ?? .other,
                    Expense.Category(rawValue: cats[1]) ?? .other,
                    count
                )
            }
            .sorted { $0.2 > $1.2 }
            .map { ($0.0, $0.1) }
    }
    
    // Helper function to calculate days in period
    private func calculateDaysInPeriod() -> Double {
        switch selectedTimeFrame {
        case .week:
            return 7
        case .month:
            return 30
        case .threeMonths:
            return 90
        case .sixMonths:
            return 180
        case .year:
            return 365
        }
    }
    
    // Helper function for consecutive days calculation
    private func findConsecutiveSpendingDays() -> Int {
        let calendar = Calendar.current
        let sortedDates = filteredExpenses.map { $0.date }.sorted()
        var maxConsecutive = 1
        var currentConsecutive = 1
        
        for i in 1..<sortedDates.count {
            let previousDate = calendar.startOfDay(for: sortedDates[i-1])
            let currentDate = calendar.startOfDay(for: sortedDates[i])
            
            if calendar.dateComponents([.day], from: previousDate, to: currentDate).day == 1 {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                currentConsecutive = 1
            }
        }
        
        return maxConsecutive
    }
    
    private func generateRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Category-based recommendation
        if let topCategory = categoryData.first {
            let monthlyAverage = topCategory.amount / 3 // Assuming 3 months of data
            let targetBudget = (monthlyAverage * 0.8).formatted(.currency(code: expenseManager.selectedCurrency))
            recommendations.append(Recommendation(
                title: "Optimize \(topCategory.name) Spending",
                description: "Set a monthly budget of \(targetBudget) for \(topCategory.name) to reduce spending by 20%.",
                icon: "chart.pie",
                color: .purple,
                potentialSaving: monthlyAverage * 0.2
            ))
        }
        
        // Weekend vs Weekday Analysis
        let weekendExpenses = filteredExpenses.filter {
            let weekday = Calendar.current.component(.weekday, from: $0.date)
            return weekday == 1 || weekday == 7
        }
        let weekendTotal = weekendExpenses.reduce(0) { sum, expense in
            sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
        if weekendTotal > totalSpendingInSelectedCurrency * 0.4 {
            recommendations.append(Recommendation(
                title: "Weekend Budget Plan",
                description: "Your weekend spending is high. Try setting a specific weekend budget and planning activities in advance.",
                icon: "calendar.badge.clock",
                color: .orange,
                potentialSaving: weekendTotal * 0.3
            ))
        }
        
        // Recurring Subscriptions Analysis
        let subscriptionExpenses = filteredExpenses.filter { $0.category == .subscription }
        let subscriptionTotal = subscriptionExpenses.reduce(0) { sum, expense in
            sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
        if subscriptionTotal > totalSpendingInSelectedCurrency * 0.1 {
            recommendations.append(Recommendation(
                title: "Review Subscriptions",
                description: "Your subscription costs are \(subscriptionTotal.formatted(.currency(code: expenseManager.selectedCurrency))) per month. Consider reviewing unused services.",
                icon: "repeat.circle",
                color: .blue,
                potentialSaving: subscriptionTotal * 0.25
            ))
        }
        
        // Dining vs Groceries Analysis
        let diningExpenses = filteredExpenses.filter { $0.category == .dining }.reduce(0) { sum, expense in
            sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
        let groceryExpenses = filteredExpenses.filter { $0.category == .groceries }.reduce(0) { sum, expense in
            sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
        }
        if diningExpenses > groceryExpenses * 1.5 {
            let potentialSaving = diningExpenses * 0.3
            recommendations.append(Recommendation(
                title: "Balance Food Expenses",
                description: "You spend significantly more on dining out than groceries. Consider meal planning to save.",
                icon: "fork.knife",
                color: .green,
                potentialSaving: potentialSaving
            ))
        }
        
        // Late Night Spending Pattern
        let lateNightExpenses = filteredExpenses.filter {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 22 || hour < 5
        }
        if !lateNightExpenses.isEmpty {
            let lateNightTotal = lateNightExpenses.reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
            recommendations.append(Recommendation(
                title: "Late Night Spending",
                description: "You have significant late-night purchases. Consider setting a cutoff time for non-essential spending.",
                icon: "moon.stars",
                color: .indigo,
                potentialSaving: lateNightTotal * 0.5
            ))
        }
        
        // Impulse Purchase Detection
        let smallTransactions = filteredExpenses.filter {
            let amount = expenseManager.getConvertedAmount($0, to: expenseManager.selectedCurrency)
            return amount < dailyAverage * 0.1 && $0.category != .groceries
        }
        if smallTransactions.count > filteredExpenses.count / 4 {
            let impulseTotal = smallTransactions.reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
            recommendations.append(Recommendation(
                title: "Reduce Impulse Buys",
                description: "You have many small purchases. Try the 24-hour rule before making non-essential purchases.",
                icon: "cart.badge.minus",
                color: .red,
                potentialSaving: impulseTotal * 0.6
            ))
        }
        
        // Savings Opportunity
        if essentialSpendingPercentage < 50 {
            let discretionaryAmount = totalSpendingInSelectedCurrency * (1 - essentialSpendingPercentage/100)
            recommendations.append(Recommendation(
                title: "Savings Opportunity",
                description: "Your essential expenses are low. Consider automating \(Int((discretionaryAmount * 0.2).rounded()))% of discretionary income to savings.",
                icon: "leaf.arrow.circlepath",
                color: .green,
                potentialSaving: discretionaryAmount * 0.2
            ))
        }
        
        return recommendations
    }
    
    private func analyzeCategoryTrends() -> [CategoryAnalysis] {
        return categoryData.map { category in
            let previousAmount = calculatePreviousPeriodAmount(for: category.name)
            let currentAmount = category.amount
            let changePercentage = previousAmount > 0 ?
                ((currentAmount - previousAmount) / previousAmount) * 100 : 0
            let percentage = currentAmount / totalSpendingInSelectedCurrency
            
            return CategoryAnalysis(
                category: Expense.Category(rawValue: category.name) ?? .other,
                amount: currentAmount,
                trend: generateTrendDescription(changePercentage),
                changePercentage: changePercentage,
                percentage: percentage
            )
        }
    }
    
    private func calculatePreviousPeriodAmount(for category: String) -> Double {
        // Implementation similar to previousPeriodSpending but filtered by category
        0 // Placeholder
    }
    
    private func generateTrendDescription(_ change: Double) -> String {
        if change > 20 {
            return "Significant increase from last period"
        } else if change > 0 {
            return "Slight increase from last period"
        } else if change < -20 {
            return "Significant decrease from last period"
        } else if change < 0 {
            return "Slight decrease from last period"
        }
        return "Stable spending pattern"
    }
    
    // Helper functions for icons and colors
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
    
    private func categoryColor(for category: Expense.Category) -> Color {
        switch category.group {
        case .essential: return .blue
        case .lifestyle: return .purple
        case .personalCare: return .pink
        case .financial: return .green
        case .miscellaneous: return .gray
        }
    }
    
    // Add KeyMetricView
    private struct KeyMetricView: View {
        let title: String
        let value: Double
        var target: Double? = nil
        var isPositive: Bool = false
        var isCurrency: Bool = false
        var format: String = "%.2f"
        var icon: String? = nil
        var isLoading: Bool = false
        @EnvironmentObject private var expenseManager: ExpenseManager
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundStyle(isPositive ? .green : .primary)
                    }
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    HStack(spacing: 4) {
                        if isCurrency {
                            Text(value, format: .currency(code: expenseManager.selectedCurrency))
                        } else {
                            Text(String(format: format, value))
                        }
                        
                        if let target = target {
                            let change = ((value - target) / target) * 100
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(isPositive ? (change <= 0 ? .green : .red) : (change <= 0 ? .red : .green))
                                .font(.caption)
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(isPositive ? .green : .primary)
                }
            }
        }
    }
    
    // Add QuickStatView
    private struct QuickStatView: View {
        let title: String
        let value: Double
        let icon: String
        let color: Color
        var isCount: Bool = false
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(color)
                    
                    Group {
                        if isCount {
                            Text("\(max(0, Int(value.isFinite ? value : 0)))")
                        } else {
                            // Format percentage with one decimal place
                            Text(String(format: "%.1f%%", value.isFinite ? value : 0))
                        }
                    }
                    .font(.title3.bold())
                    
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }
    
    // Add QuickStatDetailView
    private struct QuickStatDetailView: View {
        let type: TrendsView.QuickStatType
        let timeFrame: TrendsView.TimeFrame
        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme
        @EnvironmentObject private var expenseManager: ExpenseManager
        
        // Add computed properties
        private var expenses: [Expense] {
            let baseExpenses = filteredExpensesByTimeFrame
            switch type {
            case .essential:
                return baseExpenses.filter { expense in
                    [.groceries, .utilities, .rent, .healthcare, .transport].contains(expense.category)
                }
            case .discretionary:
                return baseExpenses.filter { expense in
                    [.entertainment, .shopping, .travel, .fitness, .dining].contains(expense.category)
                }
            case .largeExpenses:
                let average = calculateDailyAverage(for: baseExpenses)
                return baseExpenses.filter {
                    expenseManager.getConvertedAmount($0, to: expenseManager.selectedCurrency) > average * 2
                }
            }
        }
        
        private var filteredExpensesByTimeFrame: [Expense] {
            let calendar = Calendar.current
            let now = Date()
            
            return expenseManager.expenses.filter { expense in
                switch timeFrame {
                case .week:
                    let weekStart = calendar.startOfWeek(for: now)
                    return expense.date >= weekStart
                case .month:
                    return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
                case .threeMonths:
                    let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                    return expense.date >= threeMonthsAgo
                case .sixMonths:
                    let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
                    return expense.date >= sixMonthsAgo
                case .year:
                    return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
                }
            }
        }
        
        private var totalAmount: Double {
            expenses.reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        }
        
        private var totalSpending: Double {
            filteredExpensesByTimeFrame.reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        }
        
        private var categorizedExpenses: [Expense.Category: Double] {
            Dictionary(grouping: expenses, by: { $0.category })
                .mapValues { expenses in
                    expenses.reduce(0) { sum, expense in
                        sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
                    }
                }
        }
        
        private func calculateDailyAverage(for expenses: [Expense]) -> Double {
            let total = expenses.reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
            let days = Double(timeFrame == .month ? 30 : 
                             timeFrame == .threeMonths ? 90 :
                             timeFrame == .sixMonths ? 180 : 365)
            return total / days
        }
        
        private func categoryColor(for category: Expense.Category) -> Color {
            switch category.group {
            case .essential: return .blue
            case .lifestyle: return .purple
            case .personalCare: return .pink
            case .financial: return .green
            case .miscellaneous: return .orange
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
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Card
                        VStack(spacing: 8) {
                            Text(type.rawValue)
                                .font(.headline)
                            Text(totalAmount, format: .currency(code: expenseManager.selectedCurrency))
                                .font(.title.bold())
                            if type != .largeExpenses {
                                Text("\(Int((totalAmount / totalSpending) * 100))% of total spending")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                        )
                        
                        Divider()
                            .background(Color(uiColor: .separator))
                        
                        // Category Breakdown
                        if type != .largeExpenses {
                            categoryBreakdown
                        }
                        
                        Divider()
                            .background(Color(uiColor: .separator))
                        
                        // Expense List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transactions")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(expenses.sorted(by: { $0.date > $1.date }).enumerated()), id: \.element.id) { index, expense in
                                    VStack(spacing: 0) {
                                        ExpenseRowView(expense: expense)
                                            .padding(.horizontal)
                                            .background(Color(uiColor: .systemBackground))
                                        
                                        if index < expenses.count - 1 {
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
                    }
                    .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(type.rawValue)
                .toolbar {
                    Button("Done") { dismiss() }
                }
            }
        }
        
        private var categoryBreakdown: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category Breakdown")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                VStack(spacing: 0) {
                    ForEach(Array(categorizedExpenses.sorted(by: { $0.value > $1.value }).enumerated()), id: \.element.key) { index, item in
                        VStack(spacing: 0) {
                            HStack {
                                Circle()
                                    .fill(categoryColor(for: item.key))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: categoryIcon(for: item.key))
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                    }
                                Text(item.key.rawValue)
                                Spacer()
                                Text(item.value, format: .currency(code: expenseManager.selectedCurrency))
                                    .bold()
                            }
                            .padding()
                            
                            if index < categorizedExpenses.count - 1 {
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
        }
        
        // ... rest of the implementation remains the same
    }
    
    // Add missing computed properties
    private var scoreColor: Color {
        let score = calculateSpendingHealthScore()
        let wellness = getWellnessDescription(score: score)
        return wellness.color
    }
    
    private var previousDailyAverage: Double {
        previousPeriodSpending / Double(selectedTimeFrame == .month ? 30 : 
                                      selectedTimeFrame == .threeMonths ? 90 :
                                      selectedTimeFrame == .sixMonths ? 180 : 365)
    }
    
    private var essentialSpendingPercentage: Double {
        let essentialCategories: Set<Expense.Category> = [.groceries, .dining, .transport, .utilities, .rent, .healthcare]
        let essentialTotal = filteredExpenses
            .filter { essentialCategories.contains($0.category) }
            .reduce(0) { $0 + expenseManager.getConvertedAmount($1, to: expenseManager.selectedCurrency) }
        return (essentialTotal / totalSpendingInSelectedCurrency) * 100
    }
    
    private var discretionarySpendingPercentage: Double {
        let discretionaryCategories: Set<Expense.Category> = [.entertainment, .shopping, .travel, .fitness, .education, .subscription]
        let discretionaryTotal = filteredExpenses
            .filter { discretionaryCategories.contains($0.category) }
            .reduce(0) { $0 + expenseManager.getConvertedAmount($1, to: expenseManager.selectedCurrency) }
        return (discretionaryTotal / totalSpendingInSelectedCurrency) * 100
    }
    
    private var largeTransactionsCount: Int {
        filteredExpenses.filter { expense in
            expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency) > dailyAverage * 2
        }.count
    }
    
    private func calculateSavingsPotential() -> Double {
        // Define discretionary categories
        let discretionaryCategories: Set<Expense.Category> = [
            .entertainment, 
            .shopping, 
            .dining, 
            .subscription, 
            .travel, 
            .beauty
        ]
        
        // Get total discretionary spending for the selected period
        let discretionaryTotal = filteredExpenses
            .filter { discretionaryCategories.contains($0.category) }
            .reduce(0) { total, expense in
                total + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        
        // If no discretionary spending, no savings potential
        guard discretionaryTotal > 0 else { return 0 }
        
        // Calculate monthly equivalent based on time frame
        let monthlyDiscretionary: Double
        let savingsRate: Double // Different savings rate based on spending patterns
        
        switch selectedTimeFrame {
        case .week:
            monthlyDiscretionary = discretionaryTotal / 4 // Weekly potential
            savingsRate = 0.25 // 25% for weekly view
        case .month:
            monthlyDiscretionary = discretionaryTotal
            savingsRate = 0.2 // 20% for monthly view
            
        case .threeMonths:
            monthlyDiscretionary = discretionaryTotal / 3
            // Higher savings rate for longer term planning
            savingsRate = 0.25 // 25% for quarterly view
            
        case .sixMonths:
            monthlyDiscretionary = discretionaryTotal / 6
            savingsRate = 0.3 // 30% for half-yearly view
            
        case .year:
            monthlyDiscretionary = discretionaryTotal / 12
            savingsRate = 0.35 // 35% for yearly view
        }
        
        // Calculate base monthly savings potential
        let monthlyPotential = monthlyDiscretionary * savingsRate
        
        // Factor in spending patterns
        let adjustedMonthlyPotential = adjustSavingsPotential(
            basePotential: monthlyPotential,
            discretionaryTotal: discretionaryTotal
        )
        
        // Scale back to selected time period
        switch selectedTimeFrame {
        case .week:
            return adjustedMonthlyPotential / 4 // Weekly potential
        case .month:
            return adjustedMonthlyPotential
        case .threeMonths:
            return adjustedMonthlyPotential * 3
        case .sixMonths:
            return adjustedMonthlyPotential * 6
        case .year:
            return adjustedMonthlyPotential * 12
        }
    }
    
    // Helper function to adjust savings potential based on spending patterns
    private func adjustSavingsPotential(basePotential: Double, discretionaryTotal: Double) -> Double {
        var adjustmentMultiplier = 1.0
        
        // Adjust based on essential vs discretionary ratio
        if essentialSpendingPercentage < 40 {
            // More room for savings if essential spending is low
            adjustmentMultiplier *= 1.2
        } else if essentialSpendingPercentage > 60 {
            // Less room for savings if essential spending is high
            adjustmentMultiplier *= 0.8
        }
        
        // Adjust based on spending consistency
        let consistency = calculateSpendingConsistency()
        if consistency > 0.7 {
            // More predictable spending patterns allow for better savings
            adjustmentMultiplier *= 1.1
        }
        
        // Adjust based on large transactions
        if largeTransactionsCount > filteredExpenses.count / 10 {
            // Many large transactions suggest potential for optimization
            adjustmentMultiplier *= 1.15
        }
        
        return basePotential * adjustmentMultiplier
    }
    
    // Add supporting structures and computed properties
    private struct MonthlySpending: Identifiable {
        let month: String
        let amount: Double
        var id: String { month }
    }
    
    private var monthlySpendingData: [MonthlySpending] {
        let calendar = Calendar.current
        let now = Date()
        var result: [MonthlySpending] = []
        
        // Get last 6 months of data
        for monthOffset in (0..<6).reversed() {
            guard let date = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            
            let monthStart = calendar.startOfMonth(for: date)
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? date
            
            let monthlyTotal = expenseManager.expenses
                .filter { $0.date >= monthStart && $0.date <= monthEnd }
                .reduce(0) { sum, expense in
                    sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
                }
            
            let monthName = date.formatted(.dateTime.month(.abbreviated))
            result.append(MonthlySpending(month: monthName, amount: monthlyTotal))
        }
        
        return result
    }
    
    private var averageSpending: Double? {
        guard !monthlySpendingData.isEmpty else { return nil }
        let total = monthlySpendingData.reduce(0) { $0 + $1.amount }
        return total / Double(monthlySpendingData.count)
    }
    
    private struct SpendingInsight {
        let title: String
        let description: String
        let icon: String
        let color: Color
    }
    
    private var spendingInsights: [SpendingInsight] {
        var insights: [SpendingInsight] = []
        
        // Monthly Trend - Calculate actual percentage change
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month's spending
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let currentMonthEnd = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
        let currentMonthSpending = expenseManager.expenses
            .filter { $0.date >= currentMonthStart && $0.date < currentMonthEnd }
            .reduce(0.0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        
        // Get last month's spending
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        let lastMonthEnd = currentMonthStart
        let lastMonthSpending = expenseManager.expenses
            .filter { $0.date >= lastMonthStart && $0.date < lastMonthEnd }
            .reduce(0.0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        
        if lastMonthSpending > 0 {
            let change = ((currentMonthSpending - lastMonthSpending) / lastMonthSpending) * 100
            insights.append(SpendingInsight(
                title: "Monthly Trend",
                description: String(format: "Your spending has %@ by %.1f%% compared to last month",
                                 change >= 0 ? "increased" : "decreased",
                                 abs(change)),
                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                color: change >= 0 ? .red : .green
            ))
        } else if currentMonthSpending > 0 {
            // Handle case when there's no last month data but there is current month spending
            insights.append(SpendingInsight(
                title: "Monthly Trend",
                description: "First month of tracking expenses",
                icon: "star.fill",
                color: .blue
            ))
        }
        
        // Rest of the insights...
        
        return insights
    }
    
    // Add helper functions for enhanced scoring
    
    private func calculateTrendPenalty(for timeFrame: TimeFrame) -> Double {
        let calendar = Calendar.current
        let now = Date()
        var penalty: Double = 0
        
        switch timeFrame {
        case .threeMonths:
            // Calculate month-by-month variance
            let monthlyTotals = getMonthlyTotals(months: 3)
            let variance = calculateVariance(monthlyTotals)
            penalty = min(15, variance * 0.5)
            
        case .sixMonths:
            // Check for sustained overspending
            let monthlyTotals = getMonthlyTotals(months: 6)
            let overBudgetMonths = monthlyTotals.filter { $0 > expenseManager.budgetSettings.monthlyBudget }.count
            penalty = Double(overBudgetMonths) * 3
            
        case .year:
            // Analyze quarterly trends
            let quarterlyTotals = getQuarterlyTotals()
            let variance = calculateVariance(quarterlyTotals)
            penalty = min(20, variance * 0.75)
            
        default:
            break
        }
        
        return penalty
    }
    
    private func getTimePeriodMultiplier() -> Double {
        switch selectedTimeFrame {
        case .week: return 0.8  // Less impact for short term
        case .month: return 1.0 // Standard impact
        case .threeMonths: return 1.2 // Higher impact
        case .sixMonths: return 1.3 // Even higher impact
        case .year: return 1.5 // Highest impact
        }
    }
    
    private func calculateMonthlyTrend(months: Int) -> Double? {
        let monthlyTotals = getMonthlyTotals(months: months)
        guard monthlyTotals.count >= 2 else { return nil }
        
        var improvementCount = 0
        for i in 1..<monthlyTotals.count {
            if monthlyTotals[i] <= monthlyTotals[i-1] {
                improvementCount += 1
            }
        }
        
        return Double(improvementCount) / Double(monthlyTotals.count - 1)
    }
    
    private func getMonthlyTotals(months: Int) -> [Double] {
        let calendar = Calendar.current
        let now = Date()
        var totals: [Double] = []
        
        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let monthTotal = filteredExpenses
                .filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
                .reduce(0) { sum, expense in
                    sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
                }
            totals.append(monthTotal)
        }
        
        return totals
    }
    
    private func getQuarterlyTotals() -> [Double] {
        let monthlyTotals = getMonthlyTotals(months: 12)
        var quarterlyTotals: [Double] = []
        
        for i in stride(from: 0, to: monthlyTotals.count, by: 3) {
            let endIndex = min(i + 3, monthlyTotals.count)
            let quarterTotal = monthlyTotals[i..<endIndex].reduce(0, +)
            quarterlyTotals.append(quarterTotal)
        }
        
        return quarterlyTotals
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }
    
    // Add this new struct to store wellness descriptions
    private struct WellnessDescription {
        let title: String
        let description: String
        let color: Color
        
        // Add computed property for background color
        var backgroundColor: Color {
            color.opacity(0.15)
        }
    }
    
    // Add this method to provide period-specific feedback
    private func getWellnessDescription(score: Double) -> WellnessDescription {
        switch selectedTimeFrame {
        case .week:
            return getWeeklyWellnessDescription(score: score)
        case .month:
            return getMonthlyWellnessDescription(score: score)
        case .threeMonths:
            return getQuarterlyWellnessDescription(score: score)
        case .sixMonths:
            return getHalfYearlyWellnessDescription(score: score)
        case .year:
            return getYearlyWellnessDescription(score: score)
        }
    }
    
    private func getWeeklyWellnessDescription(score: Double) -> WellnessDescription {
        switch score {
        case 90...100:
            return WellnessDescription(
                title: "Excellent",
                description: "Great weekly budget control! Keep maintaining these spending habits.",
                color: .green
            )
        case 70..<90:
            return WellnessDescription(
                title: "Good",
                description: "Solid weekly spending. Minor adjustments could improve your score.",
                color: .blue
            )
        case 50..<70:
            return WellnessDescription(
                title: "Fair",
                description: "Consider reviewing this week's expenses and plan for next week.",
                color: .yellow
            )
        case 30..<50:
            return WellnessDescription(
                title: "Warning",
                description: "This week's spending needs attention. Try to reduce non-essential expenses.",
                color: .orange
            )
        default:
            return WellnessDescription(
                title: "Critical",
                description: "Immediate action needed. Review and cut back on spending.",
                color: .red
            )
        }
    }
    
    private func getMonthlyWellnessDescription(score: Double) -> WellnessDescription {
        switch score {
        case 90...100:
            return WellnessDescription(
                title: "Excellent",
                description: "Outstanding monthly financial management! Your budget control is exemplary.",
                color: .green
            )
        case 70..<90:
            return WellnessDescription(
                title: "Good",
                description: "Your monthly spending is well-managed with room for minor optimization.",
                color: .blue
            )
        case 50..<70:
            return WellnessDescription(
                title: "Fair",
                description: "Monthly spending needs attention. Review your budget allocations.",
                color: .yellow
            )
        case 30..<50:
            return WellnessDescription(
                title: "Warning",
                description: "Your monthly expenses are high. Consider creating a stricter budget.",
                color: .orange
            )
        default:
            return WellnessDescription(
                title: "Critical",
                description: "Monthly spending is significantly high. Immediate budget revision needed.",
                color: .red
            )
        }
    }
    
    private func getQuarterlyWellnessDescription(score: Double) -> WellnessDescription {
        switch score {
        case 90...100:
            return WellnessDescription(
                title: "Excellent",
                description: "Outstanding 3-month trend! Your long-term financial planning is working well.",
                color: .green
            )
        case 70..<90:
            return WellnessDescription(
                title: "Good",
                description: "Consistent quarterly performance. Focus on maintaining stable spending patterns.",
                color: .blue
            )
        case 50..<70:
            return WellnessDescription(
                title: "Fair",
                description: "Your quarterly trend shows some volatility. Consider setting quarterly budget goals.",
                color: .yellow
            )
        case 30..<50:
            return WellnessDescription(
                title: "Warning",
                description: "Quarterly spending patterns need attention. Look for recurring overspending areas.",
                color: .orange
            )
        default:
            return WellnessDescription(
                title: "Critical",
                description: "3-month trend shows consistent overspending. Time for a major financial review.",
                color: .red
            )
        }
    }
    
    private func getHalfYearlyWellnessDescription(score: Double) -> WellnessDescription {
        switch score {
        case 90...100:
            return WellnessDescription(
                title: "Excellent",
                description: "Exceptional 6-month financial management! Your long-term strategy is working perfectly.",
                color: .green
            )
        case 70..<90:
            return WellnessDescription(
                title: "Good",
                description: "Strong 6-month performance. Your financial habits are building good momentum.",
                color: .blue
            )
        case 50..<70:
            return WellnessDescription(
                title: "Fair",
                description: "Your 6-month trend needs attention. Consider reviewing your financial goals.",
                color: .yellow
            )
        case 30..<50:
            return WellnessDescription(
                title: "Warning",
                description: "Half-yearly spending patterns show concerning trends. Time for strategic changes.",
                color: .orange
            )
        default:
            return WellnessDescription(
                title: "Critical",
                description: "6-month performance indicates serious financial stress. Consider professional advice.",
                color: .red
            )
        }
    }
    
    private func getYearlyWellnessDescription(score: Double) -> WellnessDescription {
        switch score {
        case 90...100:
            return WellnessDescription(
                title: "Excellent",
                description: "Outstanding yearly financial management! You've maintained exceptional control over long-term spending.",
                color: .green
            )
        case 70..<90:
            return WellnessDescription(
                title: "Good",
                description: "Strong yearly performance. Your financial habits show consistent discipline.",
                color: .blue
            )
        case 50..<70:
            return WellnessDescription(
                title: "Fair",
                description: "Annual review suggests need for improvement. Consider long-term financial planning.",
                color: .yellow
            )
        case 30..<50:
            return WellnessDescription(
                title: "Warning",
                description: "Yearly trends show persistent issues. Time for a comprehensive financial overhaul.",
                color: .orange
            )
        default:
            return WellnessDescription(
                title: "Critical",
                description: "Annual performance indicates severe financial stress. Seek professional financial advice.",
                color: .red
            )
        }
    }
    
    // Add helper function for wellness icons
    private func getWellnessIcon(score: Double) -> String {
        switch score {
        case 90...100: return "star.circle.fill"
        case 70..<90: return "checkmark.circle.fill"
        case 50..<70: return "exclamationmark.circle.fill"
        case 30..<50: return "exclamationmark.triangle.fill"
        default: return "xmark.circle.fill"
        }
    }
    
    // Add this helper method to calculate weekly change
    private func calculateWeeklyChange() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current week's spending
        let currentWeekStart = calendar.startOfWeek(for: now)
        let currentWeekSpending = filteredExpenses
            .filter { $0.date >= currentWeekStart }
            .reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        
        // Get previous week's spending
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        let previousWeekEnd = calendar.date(byAdding: .day, value: -1, to: currentWeekStart)!
        let previousWeekSpending = expenseManager.expenses
            .filter { $0.date >= previousWeekStart && $0.date <= previousWeekEnd }
            .reduce(0) { sum, expense in
                sum + expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
            }
        
        // Calculate percentage change
        if previousWeekSpending > 0 {
            return ((currentWeekSpending - previousWeekSpending) / previousWeekSpending) * 100
        }
        return 0
    }
}

// Category Detail Sheet
struct CategoryDetailSheet: View {
    let category: Expense.Category
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Implementation of detailed category analysis
                    Text("Category Detail View Coming Soon")
                }
            }
            .background(.background)
            .navigationTitle(category.rawValue)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    TrendsView()
        .environmentObject(ExpenseManager())
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

// Helper extension for Calendar
extension Calendar {
    func startOfYear(for date: Date) -> Date {
        let components = dateComponents([.year], from: date)
        return self.date(from: components) ?? date
    }
}

// Add helper extension for Calendar
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
} 