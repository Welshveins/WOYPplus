//
//  FoodPickerListView.swift
//  WOYPplus
//
//  Created by Chris Davies on 16/03/2026.
//

import SwiftUI
import SwiftData

struct FoodPickerListView: View {

    enum Mode {
        case basics
        case myFoods
        case allFoods

        var title: String {
            switch self {
            case .basics: return "Basics"
            case .myFoods: return "My foods"
            case .allFoods: return "Foods"
            }
        }
    }

    @Environment(\.modelContext) private var ctx
    @Query(sort: \Food.createdAt, order: .forward) private var foodsByCreatedAt: [Food]
    @Query(sort: \Food.name) private var foodsByName: [Food]

    let mode: Mode
    let onPick: (Food) -> Void
    let onClose: () -> Void

    @State private var queryText = ""

    var body: some View {
        List {
            Section {
                TextField("Search foods", text: $queryText)
            }

            if filtered.isEmpty {
                Section {
                    Text("No foods found.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(mode.title) {
                    ForEach(filtered) { f in
                        Button {
                            onPick(f)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.name)
                                    .font(.headline)

                                Text("\(Int(f.kcalPer100g.rounded())) kcal per 100g")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
        .task {
            FoodSeeder.seedIfNeeded(into: ctx)
        }
    }

    private var baseList: [Food] {
        switch mode {
        case .allFoods:
            return foodsByName

        case .basics:
            let earliest = Array(foodsByCreatedAt.prefix(60))
            return earliest.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        case .myFoods:
            let latest = Array(foodsByCreatedAt.suffix(80))
            return latest.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var filtered: [Food] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return baseList }
        return baseList.filter { $0.name.lowercased().contains(q) }
    }
}
