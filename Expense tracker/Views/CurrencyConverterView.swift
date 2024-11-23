import SwiftUI

struct CurrencyConverterView: View {
    @EnvironmentObject private var expenseManager: ExpenseManager
    @State private var amount = ""
    @State private var fromCurrency = "USD"
    @State private var toCurrency = "EUR"
    @State private var isFlipping = false
    @State private var selectedTab = 0
    @FocusState private var amountIsFocused: Bool

    let currencies = ExpenseManager.availableCurrencies

    // Break down the conversion logic
    private func convert(_ inputAmount: String) -> Double? {
        guard let amount = Double(inputAmount) else { return nil }
        return expenseManager.currencyManager.convert(amount, from: fromCurrency, to: toCurrency)
    }

    var convertedAmount: Double? {
        return convert(amount)
    }

    // Break down menu content into separate view
    private func currencyMenuContent(for selection: String, action: @escaping (String) -> Void) -> some View {
        ForEach(currencies, id: \.self) { currency in
            Button {
                action(currency)
            } label: {
                HStack {
                    Text(currency)
                    if currency == selection {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            // From Currency Menu
                            Menu {
                                currencyMenuContent(for: fromCurrency) { currency in
                                    fromCurrency = currency
                                }
                            } label: {
                                currencyPillView(currency: fromCurrency, isSource: true)
                            }

                            // Swap Button
                            Button {
                                withAnimation(.spring()) {
                                    isFlipping = true
                                    swap(&fromCurrency, &toCurrency)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isFlipping = false
                                }
                            } label: {
                                swapButtonView
                            }

                            // To Currency Menu
                            Menu {
                                currencyMenuContent(for: toCurrency) { currency in
                                    toCurrency = currency
                                }
                            } label: {
                                currencyPillView(currency: toCurrency, isSource: false)
                            }
                        }

                        VStack(spacing: 12) {
                            HStack {
                                Text(fromCurrency)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 40, weight: .bold))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    #if os(iOS)
                                    .onChange(of: amount) { newValue in
                                        let filtered = newValue.filter { "0123456789.".contains($0) }
                                        if filtered != newValue {
                                            amount = filtered
                                        }
                                    }
                                    #endif
                                    .focused($amountIsFocused)
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                amountIsFocused = false
                                            }
                                        }
                                    }
                            }

                            Divider()

                            HStack {
                                Text(toCurrency)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let converted = convertedAmount {
                                    Text(converted, format: .currency(code: toCurrency))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("0.00")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(20)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)

                    // Additional sections omitted for brevity
                }
                .padding(.vertical)
            }
            .navigationTitle("Currency Converter")
            .toolbar {
                if expenseManager.currencyManager.isLoading {
                    ProgressView()
                } else {
                    Button {
                        expenseManager.currencyManager.fetchExchangeRates()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - Supporting Views
    private func currencyPillView(currency: String, isSource: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: currencySymbol(for: currency))
                .font(.headline)
                .imageScale(.large)
            Text(currency)
                .font(.headline)
            Image(systemName: "chevron.down")
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .background(isSource ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        .foregroundStyle(isSource ? .blue : .green)
        .clipShape(Capsule())
        .accessibilityLabel(isSource ? "From currency: \(currency)" : "To currency: \(currency)")
    }
    
    private var swapButtonView: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.1), radius: 5)
            
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(isFlipping ? 180 : 0))
        }
        .accessibilityLabel("Swap currencies")
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
        case "SEK": return "swedishkronasign.circle.fill"  // Added SEK symbol
        default: return "dollarsign.circle.fill"
        }
    }
}

#Preview {
    CurrencyConverterView()
        .environmentObject(ExpenseManager())
}
