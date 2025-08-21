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

// MARK: - Dimensions Field with Unit Picker
struct DimensionsFieldRow: View {
    @Binding var length: String
    @Binding var width: String
    @Binding var height: String
    @Binding var unit: String
    @Binding var isEditing: Bool
    
    private let units = ["inches", "feet", "cm", "m"]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Dimensions")
                    .foregroundColor(.primary)
                Spacer()
                Picker("Unit", selection: $unit) {
                    ForEach(units, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!isEditing)
            }
            
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", text: $length)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .disabled(!isEditing)
                }
                
                Text("×")
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                
                VStack(spacing: 4) {
                    Text("W")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", text: $width)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .disabled(!isEditing)
                }
                
                Text("×")
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                
                VStack(spacing: 4) {
                    Text("H")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", text: $height)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .disabled(!isEditing)
                }
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Weight Field with Unit Picker
struct WeightFieldRow: View {
    @Binding var value: String
    @Binding var unit: String
    @Binding var isEditing: Bool
    
    private let units = ["lbs", "kg", "oz", "g"]
    
    var body: some View {
        HStack {
            Text("Weight")
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 80)
                    .disabled(!isEditing)
                    .foregroundColor(isEditing ? .primary : .secondary)
                
                Picker("Unit", selection: $unit) {
                    ForEach(units, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!isEditing)
            }
        }
    }
}

// MARK: - Percentage Field
struct PercentageFieldRow: View {
    let label: String
    @Binding var value: Double?
    @Binding var isEditing: Bool
    
    @State private var localStringValue: String = ""
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 0) {
                TextField("0", text: $localStringValue)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 80)
                    .disabled(!isEditing)
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .onChange(of: localStringValue) { _, newValue in
                        // Remove any non-numeric characters except decimal point
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        if filtered != newValue {
                            localStringValue = filtered
                        }
                        
                        // Update the bound value
                        if let doubleValue = Double(filtered) {
                            value = doubleValue / 100.0 // Convert percentage to decimal
                        } else if filtered.isEmpty {
                            value = nil
                        }
                    }
                
                Text("%")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if let value = value {
                localStringValue = String(format: "%.1f", value * 100) // Convert decimal to percentage
            } else {
                localStringValue = ""
            }
        }
        .onChange(of: value) { _, newValue in
            if let newValue = newValue {
                localStringValue = String(format: "%.1f", newValue * 100)
            } else {
                localStringValue = ""
            }
        }
    }
}

// MARK: - Condition Picker Field
struct ConditionPickerRow: View {
    @Binding var condition: String
    @Binding var isEditing: Bool
    
    private let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
    
    var body: some View {
        HStack {
            Text("Condition")
                .foregroundColor(.primary)
            Spacer()
            
            if isEditing {
                Picker("Condition", selection: $condition) {
                    Text("Select...").tag("")
                    ForEach(conditions, id: \.self) { condition in
                        Text(condition).tag(condition)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text(condition.isEmpty ? "None" : condition)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Currency Field (similar to PriceFieldRow)
struct CurrencyFieldRow: View {
    let label: String
    @Binding var value: Decimal?
    @Binding var isEditing: Bool
    @FocusState private var isFocused: Bool
    
    @State private var localStringValue: String = ""
    
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
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 0) {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("", text: $localStringValue)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .focused($isFocused)
                    .frame(minWidth: 60, maxWidth: 75, alignment: .trailing)
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .disabled(!isEditing)
                    .onChange(of: localStringValue) { _, newValue in
                        let filteredValue = newValue.filter { $0.isNumber }
                        
                        if newValue != filteredValue {
                            localStringValue = filteredValue
                        }
                        
                        let formattedValue = formattedPriceString(filteredValue)
                        
                        if !formattedValue.isEmpty {
                            localStringValue = formattedValue
                            
                            if let decimalValue = Decimal(string: filteredValue) {
                                let finalValue = decimalValue / 100
                                if finalValue != value {
                                    value = finalValue
                                }
                            }
                        } else {
                            value = nil
                        }
                    }
                    .overlay(
                        Group {
                            if localStringValue.isEmpty && !isFocused {
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
            if let value = value {
                let scaledValue = value * 100
                let intValue = Int(NSDecimalNumber(decimal: scaledValue).rounding(accordingToBehavior: nil).intValue)
                localStringValue = formattedPriceString(String(intValue))
            } else {
                localStringValue = ""
            }
        }
        .onChange(of: value) { _, newValue in
            if let newValue = newValue {
                let scaledValue = newValue * 100
                let intValue = Int(NSDecimalNumber(decimal: scaledValue).rounding(accordingToBehavior: nil).intValue)
                localStringValue = formattedPriceString(String(intValue))
            } else {
                localStringValue = ""
            }
        }
    }
}

#Preview {
    FormTextFieldRow(label: "Title", text: .constant("Test Title"), isEditing: .constant(false))
}
