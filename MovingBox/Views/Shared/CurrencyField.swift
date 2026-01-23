//
//  CurrencyField.swift
//  MovingBox
//
//  Created by Claude on 1/18/26.
//

import SwiftUI

struct CurrencyField: View {
    let title: String
    @Binding var value: Decimal
    let isEnabled: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isEnabled {
                TextField("Amount", value: $value, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            } else {
                Text(value, format: .currency(code: "USD"))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Form {
        CurrencyField(title: "Amount", value: .constant(1234.56), isEnabled: true)
        CurrencyField(title: "Read Only", value: .constant(1234.56), isEnabled: false)
    }
}
