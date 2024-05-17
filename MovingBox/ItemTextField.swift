//
//  ItemTextField.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import Foundation
import SwiftUI

struct ItemTextField: View {
    var text: String
    @State var entry: String

    var body: some View {
        HStack {
            Text(text)
            TextField("Enter \(text)", text: $entry)
        }
    }
}

#Preview {
    ItemTextField(text: "Title", entry: "")
}
