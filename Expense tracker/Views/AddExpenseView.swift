import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    @State private var amount = ""
    @State private var category = Expense.Category.groceries
    @State private var date = Date()
    @State private var note = ""
    @State private var currency = "USD"
    @State private var showingCategoryPicker = false
    
    let currencies = ExpenseManager.availableCurrencies
    
    private var convertedAmount: Double? {
        guard let amount = Double(amount) else { return nil }
        return expenseManager.currencyManager.convert(
            amount,
            from: currency,
            to: expenseManager.selectedCurrency
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Amount and Currency Section
                Section {
                    VStack(spacing: 16) {
                        // Amount Input with Currency
                        HStack(alignment: .center) {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 34, weight: .bold))
                                .frame(maxWidth: .infinity)
                            
                            Menu {
                                ForEach(currencies, id: \.self) { currency in
                                    Button(currency) {
                                        self.currency = currency
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(currency)
                                        .bold()
                                    Image(systemName: "chevron.down")
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Conversion Preview
                        if let converted = convertedAmount,
                           currency != expenseManager.selectedCurrency {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Converts to")
                                        .foregroundColor(.secondary)
                                }
                                .font(.subheadline)
                                
                                Text(converted, format: .currency(code: expenseManager.selectedCurrency))
                                    .font(.title3.bold())
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                } header: {
                    Text("Amount")
                }
                
                // Category Section
                Section("Category") {
                    NavigationLink {
                        CategoryPickerView(selectedCategory: $category)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(categoryColor(for: category))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: categoryIcon(for: category))
                                        .foregroundColor(.white)
                                }
                            
                            Text(category.rawValue)
                                .foregroundColor(categoryColor(for: category))
                            
                            Spacer()
                            
                            // Removed the chevron.right image since NavigationLink adds its own arrow
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Date Section
                Section("Date") {
                    DatePicker("Date", selection: $date)
                }
                
                // Note Section
                Section("Note") {
                    TextField("Add note", text: $note, axis: .vertical)
                        .lineLimit(1...5)
                }
                
                // Exchange Rate Info
                if currency != expenseManager.selectedCurrency {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exchange Rate")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("1 \(currency) = ")
                                if let rate = expenseManager.currencyManager.exchangeRates[currency] {
                                    Text(rate, format: .currency(code: expenseManager.selectedCurrency))
                                        .bold()
                                } else {
                                    Text("Loading...")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveExpense()
                    }
                    .disabled(amount.isEmpty)
                }
            }
        }
    }
    
    private func saveExpense() {
        // Clean the amount string and convert to Double
        let cleanAmount = amount.replacingOccurrences(of: ",", with: ".")
        guard let amountDouble = Double(cleanAmount) else { return }
        
        let expense = Expense(
            amount: amountDouble,
            category: category,
            date: date,
            currency: currency,
            note: note
        )
        
        expenseManager.addExpense(expense)
        dismiss()
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
    
    private func categoryColor(for category: Expense.Category) -> Color {
        switch category.group {
        case .essential: return .blue
        case .lifestyle: return .purple
        case .personalCare: return .pink
        case .financial: return .green
        case .miscellaneous: return .gray
        }
    }
}

// Update CategoryPickerView
struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: Expense.Category
    
    var body: some View {
        List {
            ForEach(Expense.Category.allCases) { category in
                Button {
                    selectedCategory = category
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        // Category Icon
                        Circle()
                            .fill(categoryColor(for: category))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: categoryIcon(for: category))
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                        
                        // Category Name
                        Text(category.rawValue)
                            .font(.headline)
                            .foregroundStyle(categoryColor(for: category))
                        
                        Spacer()
                        
                        // Selection Indicator
                        if category == selectedCategory {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(categoryColor(for: category))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.visible)
            .listRowBackground(Color(uiColor: .systemBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
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
}

#Preview {
    AddExpenseView()
        .environmentObject(ExpenseManager())
} 