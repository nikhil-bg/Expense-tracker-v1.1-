//
//  Expense_trackerApp.swift
//  Expense tracker
//
//  Created by Nikhil BG on 2024-11-17.
//

import SwiftUI

@main
struct Expense_trackerApp: App {
    @StateObject private var expenseManager = ExpenseManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(expenseManager)
                .onAppear {
                    // Initial fetch is non-async now
                    expenseManager.currencyManager.fetchExchangeRates()
                }
        }
    }
}
