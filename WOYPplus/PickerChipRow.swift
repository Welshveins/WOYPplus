import SwiftUI

struct PickerChipRow<Option: Hashable & Identifiable & CustomStringConvertible>: View {

    let title: String
    let options: [Option]
    @Binding var selection: Option
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        chip(for: option)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func chip(for option: Option) -> some View {
        let isSelected = option == selection

        return Button {
            selection = option
            onTap()
        } label: {
            Text(option.description)
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
