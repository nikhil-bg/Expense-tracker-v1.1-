//
//  ContentView.swift
//  Expense tracker
//
//  Created by Nikhil BG on 2024-11-17.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var expenseManager = ExpenseManager()
    
    var body: some View {
        TabView {
            ExpenseLogView()
                .tabItem {
                    Label("Expenses", systemImage: "list.bullet")
                }
            
            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .environmentObject(expenseManager)
    }
}

#Preview {
    ContentView()
}
