//
//  AddIngredientSourceView.swift
//  WOYPplus
//
//  Created by Chris Davies on 16/03/2026.
//

import SwiftUI

struct AddIngredientSourceView: View {

    let onScanBarcode: () -> Void
    let onManual: () -> Void
    let onBasics: () -> Void
    let onMyFoods: () -> Void
    let onAllFoods: () -> Void
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                Text("Choose the fastest way to add an ingredient.")
                    .foregroundStyle(.secondary)
            }

            Section("Add ingredient") {
                Button { onScanBarcode() } label: {
                    Label("Scan barcode", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(PressableCardStyle())

                Button { onManual() } label: {
                    Label("Manual entry", systemImage: "square.and.pencil")
                }
                .buttonStyle(PressableCardStyle())

                Button { onBasics() } label: {
                    Label("Basics", systemImage: "list.bullet")
                }
                .buttonStyle(PressableCardStyle())

                Button { onMyFoods() } label: {
                    Label("My foods", systemImage: "person.crop.circle")
                }
                .buttonStyle(PressableCardStyle())

                Button { onAllFoods() } label: {
                    Label("Add ingredient (foods)", systemImage: "fork.knife")
                }
                .buttonStyle(PressableCardStyle())
            }
        }
        .navigationTitle("Add ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
    }
}
