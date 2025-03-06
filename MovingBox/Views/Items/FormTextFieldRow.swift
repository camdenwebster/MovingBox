//
//  FormTextFieldRow.swift
//  MovingBox
//
//  Created by Camden Webster on 3/5/24.
//

import SwiftUI

struct FormTextFieldRow: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct PriceFieldRow: View {
    let label = "Price"
    @Binding var priceString: String
    @Binding var priceDecimal: Decimal
    @FocusState private var isPriceFieldFocused: Bool
    
    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.currencySymbol
    }
    
    private func formattedPriceString(_ input: String) -> String {
        // Filter out non-numeric characters
        let numericString = input.filter { $0.isNumber }
        
        if numericString.isEmpty {
            return ""
        }
        
        // Convert to a Decimal amount (divide by 100 to place decimal point)
        let amountValue = Decimal(string: numericString) ?? 0
        let amount = amountValue / 100
        
        // Format with 2 decimal places
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }
    
    var body: some View {
        HStack {
            Text("Price")
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 0) {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("", text: $priceString)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .focused($isPriceFieldFocused)
                    .frame(minWidth: 60, maxWidth: 75, alignment: .trailing)
                    .onChange(of: priceString) { oldValue, newValue in
                        // Filter and allow only numbers
                        let filteredValue = newValue.filter { $0.isNumber }
                        
                        // If the user changed the string and it doesn't match our filtered value
                        if newValue != filteredValue {
                            priceString = filteredValue
                        }
                        
                        // Format for display with decimal point
                        let formattedValue = formattedPriceString(filteredValue)
                        
                        // Only update the UI if we have a valid format and it's different
                        if !formattedValue.isEmpty && formattedValue != priceString {
                            priceString = formattedValue
                        }
                        
                        // Update the actual Decimal value for storage
                        if !filteredValue.isEmpty {
                            let numericString = filteredValue
                            if let decimalValue = Decimal(string: numericString) {
                                priceDecimal = decimalValue / 100
                            }
                        } else {
                            priceDecimal = 0
                        }
                }
                .overlay(
                    Group {
                        if priceString.isEmpty && !isPriceFieldFocused {
                            Text("0.00")
                                .foregroundColor(.gray)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    )
            }
            .frame(maxWidth: 120, alignment: .trailing)
        }
        .onAppear {
            // Convert to integer by multiplying by 100 and rounding properly
            let scaledValue = priceDecimal * Decimal(100)
            let intValue = Int(NSDecimalNumber(decimal: scaledValue).rounding(accordingToBehavior: nil).intValue)
            priceString = formattedPriceString(String(intValue))
        }
    }
}

#Preview {
    FormTextFieldRow(label: "Title", text: .constant("Test Title"))
}
