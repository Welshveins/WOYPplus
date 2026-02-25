import SwiftUI

struct HelpInstructionsView: View {

    @State private var expandedSection: String? = nil
    @State private var showingQuickAddSlotPicker = false
    @State private var quickAddSlot: MealSlot = .snacks

    var body: some View {

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                Text("Help")
                    .font(.system(size: 28, weight: .semibold))
                    .padding(.top, 8)

                Text("Everything you need to use WOYP Plus calmly and confidently.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // MARK: Quick Add

                HelpSection(
                    icon: "barcode.viewfinder",
                    title: "Quick add",
                    id: "quick",
                    expanded: $expandedSection
                ) {
                    HelpCard(
                        steps: [
                            "Open the meal you want.",
                            "Tap Add to meal → Barcode.",
                            "Scan or enter manually.",
                            "Tap Log."
                        ],
                        buttonTitle: "Open Quick add",
                        buttonIcon: "barcode.viewfinder"
                    ) {
                        quickAddSlot = .snacks
                        showingQuickAddSlotPicker = true
                    }
                }

                // MARK: Log Recipe

                HelpSection(
                    icon: "fork.knife",
                    title: "Log a recipe",
                    id: "recipe",
                    expanded: $expandedSection
                ) {
                    HelpCard(
                        steps: [
                            "Open a meal.",
                            "Tap Add to meal → Recipe.",
                            "Select a recipe.",
                            "Choose servings.",
                            "Tap Save."
                        ],
                        buttonTitle: "Open Recipes",
                        buttonIcon: "fork.knife"
                    ) {
                        quickAddSlot = .snacks
                        showingQuickAddSlotPicker = true
                    }
                }

                // MARK: Your Plate

                HelpSection(
                    icon: "camera",
                    title: "Your plate (photo estimate)",
                    id: "plate",
                    expanded: $expandedSection
                ) {
                    HelpCard(
                        steps: [
                            "Take a photo of your plate.",
                            "Fill the frame with food.",
                            "Use good light.",
                            "Toggle Focus on centre if needed.",
                            "Adjust Plate mix if the balance is different.",
                            "Edit before saving."
                        ],
                        buttonTitle: "Open Your plate",
                        buttonIcon: "camera"
                    ) {
                        quickAddSlot = .snacks
                        showingQuickAddSlotPicker = true
                    }
                }

                // MARK: Macro Rings

                HelpSection(
                    icon: "chart.pie",
                    title: "Daily & weekly macro rings",
                    id: "rings",
                    expanded: $expandedSection
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• Outer ring = most recent day.")
                        Text("• Dot shows your position in your range.")
                        Text("• Weekly view shows patterns, not perfection.")
                        Text("• No red/green judgement — awareness only.")
                    }
                    .font(.subheadline)
                }

                // MARK: Estimates

                HelpSection(
                    icon: "wand.and.stars",
                    title: "Estimates",
                    id: "estimates",
                    expanded: $expandedSection
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• An estimate is better than not logging.")
                        Text("• A small asterisk marks estimated days.")
                        Text("• You can edit any entry later.")
                        Text("• WOYP Plus prioritises calm awareness over precision.")
                    }
                    .font(.subheadline)
                }

                // MARK: Share Recipes

                HelpSection(
                    icon: "square.and.arrow.up",
                    title: "Share recipes",
                    id: "share",
                    expanded: $expandedSection
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• Open a recipe.")
                        Text("• Tap Share.")
                        Text("• Send via AirDrop, Messages or WhatsApp.")
                        Text("• Recipient taps the file to import.")
                    }
                    .font(.subheadline)
                }

                // MARK: Backup

                HelpSection(
                    icon: "arrow.up.arrow.down",
                    title: "Backup & Restore",
                    id: "backup",
                    expanded: $expandedSection
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• Export Recipe Library for recipes only.")
                        Text("• Export All Data for full backup.")
                        Text("• Save to Files, AirDrop or Messages.")
                        Text("• Import from the same screen.")
                    }
                    .font(.subheadline)

                    NavigationLink {
                        DataBackupView()
                    } label: {
                        HStack {
                            Text("Open Backup & Restore")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.woypSlate.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Color.woypSlate.opacity(0.15).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingQuickAddSlotPicker) {
            NavigationStack {
                QuickAddSheet(day: Day(date: Date()), mealSlot: quickAddSlot)
            }
        }
    }
}

//
// MARK: - Section Wrapper
//

private struct HelpSection<Content: View>: View {

    let icon: String
    let title: String
    let id: String
    @Binding var expanded: String?
    let content: Content

    init(
        icon: String,
        title: String,
        id: String,
        expanded: Binding<String?>,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.id = id
        self._expanded = expanded
        self.content = content()
    }

    var body: some View {

        VStack(spacing: 0) {

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expanded = expanded == id ? nil : id
                }
            } label: {
                HStack(spacing: 14) {

                    ZStack {
                        Circle()
                            .fill(Color.woypTerracotta.opacity(expanded == id ? 0.20 : 0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.woypTerracotta)
                    }

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    Image(systemName: expanded == id ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.woypSlate.opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            if expanded == id {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(.top, 12)
                .padding(.horizontal, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

//
// MARK: - Help Card
//

private struct HelpCard: View {

    let steps: [String]
    let buttonTitle: String
    let buttonIcon: String
    let action: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            ForEach(steps, id: \.self) { step in
                Text("• \(step)")
                    .font(.subheadline)
            }

            Button(action: action) {
                HStack {
                    Image(systemName: buttonIcon)
                        .foregroundStyle(Color.woypTerracotta)

                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.woypTerracotta.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
        }
    }
}
