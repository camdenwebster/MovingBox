//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Home Statistics") {
                    HStack {
                        Text("Number of items: ")
                        Spacer()
                        Text("0")
                    }
                    HStack {
                        Text("Number of locations:")
                        Spacer()
                        Text("0")
                    }
                }
                Section("Inventory Statistics") {
                    HStack {
                        Text("Total replacement cost")
                        Spacer()
                        Text("$0.00")
                    }
                }
            }
            .navigationTitle("Home Inventory")
        }
    }
}

#Preview {
    DashboardView()
}
