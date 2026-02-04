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
    var useSubTitle: Bool = false
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(self.text)
                .font(useSubTitle ? .title3 : .title)
                .foregroundStyle(.primary)
            if isButton {
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(.tint, in: Circle())
                    }
                }
                Spacer()
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
