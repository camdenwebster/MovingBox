//
//  DashboardNavigationLinkView.swift
//  MovingBox
//
//  Created by Camden Webster on 8/13/25.
//

import SwiftUI

struct DashboardSectionLabel: View {
    var text: String
    var isButton = true
    
    var body: some View {
        HStack(spacing: 8)  {
            Text(self.text)
                .font(.title)
                .foregroundStyle(.primary)
            if isButton {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

        }
        .bold()
        .padding(.horizontal)
    }
}

#Preview {
    DashboardSectionLabel(text: "Locations")
}
