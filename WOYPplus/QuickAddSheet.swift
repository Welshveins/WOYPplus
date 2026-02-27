import SwiftUI
import SwiftData

struct QuickAddSheet: View {

    @Environment(\.dismiss) private var dismiss

    let day: Day
    let mealSlot: MealSlot

    @State private var showingBarcode = false
    @State private var showingManual = false
    @State private var showingFruit = false   // ✅ NEW

    var body: some View {
        VStack(spacing: 16) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick add")
                    .font(.system(size: 22, weight: .semibold))

                Text("Scan a barcode or enter manually.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)

            // Buttons (as a single card group)
            VStack(spacing: 12) {

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

                // ✅ NEW: Fruit quick add
                bigButton(
                    title: "Fruit",
                    systemImage: "apple.logo"
                ) {
                    showingFruit = true
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.woypSlate.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingBarcode) {
            BarcodeQuickAddView(day: day, mealSlot: mealSlot)
        }
        .sheet(isPresented: $showingManual) {
            NavigationStack {
                QuickAddManualEntryView(day: day, mealSlot: mealSlot, useTimeBasedDefault: true)
            }
        }
        // ✅ NEW
        .sheet(isPresented: $showingFruit) {
            NavigationStack {
                FruitQuickAddView(day: day, mealSlot: mealSlot)
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.woypSlate.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}
