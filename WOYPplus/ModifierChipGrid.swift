//
//  ModifierChipGrid.swift
//  WOYPplus
//
//  Created by Chris Davies on 17/03/2026.
//

import SwiftUI

struct ModifierChipGrid: View {

    @Binding var selected: Set<RichAddOn>

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(RichAddOn.allCases, id: \.self) { item in
                chip(for: item)
            }
        }
    }

    private func chip(for item: RichAddOn) -> some View {
        let isOn = selected.contains(item)

        return Button {
            if isOn {
                selected.remove(item)
            } else {
                selected.insert(item)
            }
        } label: {
            Text(item.display)
                .font(.footnote.weight(.medium))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isOn ? Color.woypTeal.opacity(0.18) : Color.woypSlate.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isOn ? Color.woypTeal.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
