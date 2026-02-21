import SwiftUI

struct QuickAddSheet: View {

    @Environment(\.dismiss) private var dismiss

    let day: Day
    let mealSlot: MealSlot

    @State private var showingBarcode = false
    @State private var showingManual = false

    var body: some View {

        VStack(spacing: 18) {

            Spacer()

            bigButton(
                title: "Scan barcode",
                systemImage: "barcode.viewfinder"
            ) {
                showingBarcode = true
            }

            bigButton(
                title: "Enter manually",
                systemImage: "square.and.pencil"
            ) {
                showingManual = true
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showingBarcode) {
            BarcodeQuickAddView(day: day, mealSlot: mealSlot)
        }
        .sheet(isPresented: $showingManual) {
            NavigationStack {
                QuickAddManualEntryView(day: day, mealSlot: mealSlot)
            }
        }
    }

    private func bigButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            HStack(spacing: 14) {

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.woypSlate.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}
