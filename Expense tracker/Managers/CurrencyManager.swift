import Foundation

class CurrencyManager: ObservableObject {
    @Published var exchangeRates: [String: Double] = [:]
    @Published var isLoading = false
    private let apiKey = "YOUR_API_KEY"
    
    func fetchExchangeRatesAsync() async {
        guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/USD") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.exchangeRates = response.rates
                self.isLoading = false
            }
        } catch {
            print("Error fetching exchange rates: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    // Keep the old method for backward compatibility
    func fetchExchangeRates() {
        Task {
            await fetchExchangeRatesAsync()
        }
    }
    
    func convert(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double? {
        guard let sourceRate = exchangeRates[sourceCurrency],
              let targetRate = exchangeRates[targetCurrency] else {
            return nil
        }
        
        return amount * (targetRate / sourceRate)
    }
}

// API Response Models
struct ExchangeRateResponse: Codable {
    let base: String
    let rates: [String: Double]
}

// Alternate API Response Model for FreeCurrencyAPI
struct FreeCurrencyAPIResponse: Codable {
    let data: [String: Double]
} 
