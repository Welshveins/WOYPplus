import SwiftUI

struct PickerChipRow<T: Hashable & Identifiable>: View {

    let items: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    chip(for: item)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(for item: T) -> some View {
        let isSelected = item == selection

        return Button {
            selection = item
        } label: {
            Text(label(item))
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.woypTeal.opacity(0.18) : Color.woypSlate.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.woypTeal.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
