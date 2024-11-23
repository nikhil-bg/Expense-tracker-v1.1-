import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    @EnvironmentObject private var expenseManager: ExpenseManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Circle()
                .fill(categoryColor(for: expense.category))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: categoryIcon(for: expense.category))
                        .foregroundStyle(.white)
                }
            
            // Expense Details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.category.rawValue)
                    .font(.headline)
                
                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(expense.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                // Original amount
                Text(expense.amount, format: .currency(code: expense.currency))
                    .font(.headline)
                
                // Converted amount (if different currency)
                if expense.currency != expenseManager.selectedCurrency {
                    let convertedAmount = expenseManager.getConvertedAmount(expense, to: expenseManager.selectedCurrency)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text(convertedAmount, format: .currency(code: expenseManager.selectedCurrency))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.vertical, 8)
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
    ExpenseRowView(expense: Expense(
        amount: 25.99,
        category: .groceries,
        date: Date(),
        currency: "USD",
        note: "Lunch with colleagues"
    ))
    .environmentObject(ExpenseManager())
} 