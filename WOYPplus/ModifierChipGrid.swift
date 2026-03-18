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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? Color.woypTeal : Color.primary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isOn ? Color.woypTeal.opacity(0.16) : Color.woypSlate.opacity(0.07))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isOn ? 0.22 : 0.10), lineWidth: 1)
                )
                .scaleEffect(isOn ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
    }
}
