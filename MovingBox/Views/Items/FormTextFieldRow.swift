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
    @Binding var isEditing: Bool
    var placeholder: String = ""
    
    var body: some View {
        HStack {
            Text(label)
//                .foregroundColor(isEditing ? .secondary : .primary)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(isEditing ? .primary : .secondary)
                .disabled(!isEditing)
        }
    }
}

struct PriceFieldRow: View {
    let label = "Price"
    @Binding var priceString: String
    @Binding var priceDecimal: Decimal
    @Binding var isEditing: Bool
    @FocusState private var isPriceFieldFocused: Bool
    
    @State private var localPriceString: String = ""
    
    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.currencySymbol
    }
    
    private func formattedPriceString(_ input: String) -> String {
        let numericString = input.filter { $0.isNumber }
        
        if numericString.isEmpty {
            return ""
        }
        
        guard let amountValue = Decimal(string: numericString) else {
            return ""
        }
        
        let amount = amountValue / 100
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(isEditing ? .secondary : .primary)
            Spacer()
            HStack(spacing: 0) {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("", text: $localPriceString)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .focused($isPriceFieldFocused)
                    .frame(minWidth: 60, maxWidth: 75, alignment: .trailing)
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .onChange(of: localPriceString) { _, newValue in
                        let filteredValue = newValue.filter { $0.isNumber }
                        
                        if newValue != filteredValue {
                            localPriceString = filteredValue
                        }
                        
                        let formattedValue = formattedPriceString(filteredValue)
                        
                        if !formattedValue.isEmpty {
                            localPriceString = formattedValue
                            
                            if let decimalValue = Decimal(string: filteredValue) {
                                let finalValue = decimalValue / 100
                                if finalValue != priceDecimal {
                                    priceDecimal = finalValue
                                }
                            }
                        }
                        
                        priceString = localPriceString
                    }
                    .overlay(
                        Group {
                            if localPriceString.isEmpty && !isPriceFieldFocused {
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
            let scaledValue = priceDecimal * 100
            let intValue = Int(NSDecimalNumber(decimal: scaledValue).rounding(accordingToBehavior: nil).intValue)
            localPriceString = formattedPriceString(String(intValue))
            priceString = localPriceString
        }
    }
}

#Preview {
    FormTextFieldRow(label: "Title", text: .constant("Test Title"), isEditing: .constant(false))
}
