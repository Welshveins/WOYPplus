import Foundation
import SwiftData

enum FoodSeeder {

    static func seedIfNeeded(into ctx: ModelContext) {

        // Fetch existing foods once
        let existingFoods = (try? ctx.fetch(FetchDescriptor<Food>())) ?? []
        var existingNames = Set(
            existingFoods.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )

        // Additive seeding: insert only missing names
        // NOTE: seeded foods are NOT user-created
        let seeds: [Food] = [

            // --- Basics / staples ---
            Food(
                name: "White rice - Cooked",
                kcalPer100g: 130, carbsPer100g: 28, proteinPer100g: 2.5, fatPer100g: 0.3, fibrePer100g: 0.4,
                defaultPortionName: "1 cup cooked", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Brown rice - Cooked",
                kcalPer100g: 120, carbsPer100g: 26, proteinPer100g: 2.7, fatPer100g: 0.3, fibrePer100g: 1.8,
                defaultPortionName: "1 cup cooked", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Spaghetti (cooked)",
                kcalPer100g: 158, carbsPer100g: 31, proteinPer100g: 5.8, fatPer100g: 0.9, fibrePer100g: 1.8,
                defaultPortionName: "1 bowl", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Pasta (cooked)",
                kcalPer100g: 158, carbsPer100g: 31, proteinPer100g: 5.8, fatPer100g: 0.9, fibrePer100g: 1.8,
                defaultPortionName: "1 bowl", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Pasta (dry)",
                kcalPer100g: 350, carbsPer100g: 72, proteinPer100g: 12, fatPer100g: 0.9, fibrePer100g: 1.8,
                defaultPortionName: "75g dry", defaultPortionGrams: 75,
                isUserCreated: false
            ),

            Food(
                name: "Bread",
                kcalPer100g: 265, carbsPer100g: 49, proteinPer100g: 9, fatPer100g: 3.2, fibrePer100g: 2.7,
                defaultPortionName: "1 slice", defaultPortionGrams: 40,
                isUserCreated: false
            ),

            Food(
                name: "Wrap",
                kcalPer100g: 310, carbsPer100g: 50, proteinPer100g: 8, fatPer100g: 8, fibrePer100g: 3,
                defaultPortionName: "1 wrap", defaultPortionGrams: 60,
                isUserCreated: false
            ),

            Food(
                name: "Bread roll",
                kcalPer100g: 280, carbsPer100g: 52, proteinPer100g: 9, fatPer100g: 3.5, fibrePer100g: 2.8,
                defaultPortionName: "1 roll", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            // Added staples
            Food(
                name: "Porridge oats (dry)",
                kcalPer100g: 389, carbsPer100g: 66, proteinPer100g: 17, fatPer100g: 7, fibrePer100g: 10,
                defaultPortionName: "40g dry", defaultPortionGrams: 40,
                isUserCreated: false
            ),

            Food(
                name: "Cereal (cornflakes)",
                kcalPer100g: 360, carbsPer100g: 84, proteinPer100g: 7, fatPer100g: 0.5, fibrePer100g: 3,
                defaultPortionName: "30g bowl", defaultPortionGrams: 30,
                isUserCreated: false
            ),

            Food(
                name: "Bagel",
                kcalPer100g: 250, carbsPer100g: 48, proteinPer100g: 10, fatPer100g: 2, fibrePer100g: 2.5,
                defaultPortionName: "1 bagel", defaultPortionGrams: 95,
                isUserCreated: false
            ),

            Food(
                name: "Crackers",
                kcalPer100g: 430, carbsPer100g: 72, proteinPer100g: 9, fatPer100g: 12, fibrePer100g: 3,
                defaultPortionName: "4 crackers", defaultPortionGrams: 30,
                isUserCreated: false
            ),

            Food(
                name: "Tortilla chips",
                kcalPer100g: 500, carbsPer100g: 65, proteinPer100g: 7, fatPer100g: 25, fibrePer100g: 6,
                defaultPortionName: "Small bowl", defaultPortionGrams: 30,
                isUserCreated: false
            ),

            Food(
                name: "Potato (boiled)",
                kcalPer100g: 87, carbsPer100g: 20, proteinPer100g: 2, fatPer100g: 0.1, fibrePer100g: 1.8,
                defaultPortionName: "1 medium", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Potato (baked)",
                kcalPer100g: 93, carbsPer100g: 21, proteinPer100g: 2.5, fatPer100g: 0.1, fibrePer100g: 2.2,
                defaultPortionName: "1 medium", defaultPortionGrams: 220,
                isUserCreated: false
            ),

            Food(
                name: "Potato (roast)",
                kcalPer100g: 150, carbsPer100g: 24, proteinPer100g: 2.5, fatPer100g: 5, fibrePer100g: 2.5,
                defaultPortionName: "1 serving", defaultPortionGrams: 200,
                isUserCreated: false
            ),

            // Added potatoes
            Food(
                name: "Potato (mashed)",
                kcalPer100g: 110, carbsPer100g: 17, proteinPer100g: 2.2, fatPer100g: 3.5, fibrePer100g: 2,
                defaultPortionName: "1 serving", defaultPortionGrams: 200,
                isUserCreated: false
            ),

            Food(
                name: "Sweet potato (baked)",
                kcalPer100g: 90, carbsPer100g: 21, proteinPer100g: 2, fatPer100g: 0.2, fibrePer100g: 3,
                defaultPortionName: "1 medium", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            // Added grains
            Food(
                name: "Couscous - Cooked",
                kcalPer100g: 112, carbsPer100g: 23, proteinPer100g: 3.8, fatPer100g: 0.2, fibrePer100g: 1.4,
                defaultPortionName: "1 cup cooked", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Quinoa - Cooked",
                kcalPer100g: 120, carbsPer100g: 21, proteinPer100g: 4.4, fatPer100g: 1.9, fibrePer100g: 2.8,
                defaultPortionName: "1 cup cooked", defaultPortionGrams: 185,
                isUserCreated: false
            ),

            // --- Veg ---
            Food(
                name: "Broccoli",
                kcalPer100g: 35, carbsPer100g: 7, proteinPer100g: 2.8, fatPer100g: 0.4, fibrePer100g: 3,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Carrot",
                kcalPer100g: 41, carbsPer100g: 10, proteinPer100g: 0.9, fatPer100g: 0.2, fibrePer100g: 2.8,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Green beans",
                kcalPer100g: 31, carbsPer100g: 7, proteinPer100g: 1.8, fatPer100g: 0.1, fibrePer100g: 3.4,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Salad",
                kcalPer100g: 20, carbsPer100g: 3, proteinPer100g: 1.5, fatPer100g: 0.2, fibrePer100g: 2,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Tomato",
                kcalPer100g: 18, carbsPer100g: 3.9, proteinPer100g: 0.9, fatPer100g: 0.2, fibrePer100g: 1.2,
                defaultPortionName: "1 medium", defaultPortionGrams: 120,
                isUserCreated: false
            ),

            Food(
                name: "Onion",
                kcalPer100g: 40, carbsPer100g: 9.3, proteinPer100g: 1.1, fatPer100g: 0.1, fibrePer100g: 1.7,
                defaultPortionName: "1 onion", defaultPortionGrams: 110,
                isUserCreated: false
            ),

            // Added veg
            Food(
                name: "Peas",
                kcalPer100g: 81, carbsPer100g: 14, proteinPer100g: 5.4, fatPer100g: 0.4, fibrePer100g: 5.1,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Mixed veg",
                kcalPer100g: 55, carbsPer100g: 10, proteinPer100g: 3, fatPer100g: 0.5, fibrePer100g: 3,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Sweetcorn",
                kcalPer100g: 86, carbsPer100g: 19, proteinPer100g: 3.4, fatPer100g: 1.2, fibrePer100g: 2.7,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Cucumber",
                kcalPer100g: 15, carbsPer100g: 3.6, proteinPer100g: 0.7, fatPer100g: 0.1, fibrePer100g: 0.5,
                defaultPortionName: "1/2 cucumber", defaultPortionGrams: 150,
                isUserCreated: false
            ),

            Food(
                name: "Pepper",
                kcalPer100g: 31, carbsPer100g: 6, proteinPer100g: 1, fatPer100g: 0.3, fibrePer100g: 2.1,
                defaultPortionName: "1 pepper", defaultPortionGrams: 120,
                isUserCreated: false
            ),

            Food(
                name: "Mushrooms",
                kcalPer100g: 22, carbsPer100g: 3.3, proteinPer100g: 3.1, fatPer100g: 0.3, fibrePer100g: 1,
                defaultPortionName: "80g serving", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            // --- Proteins / dairy ---
            Food(
                name: "Chicken breast (cooked)",
                kcalPer100g: 165, carbsPer100g: 0, proteinPer100g: 31, fatPer100g: 3.6, fibrePer100g: 0,
                defaultPortionName: "1 portion", defaultPortionGrams: 150,
                isUserCreated: false
            ),

            Food(
                name: "Chicken breast (raw)",
                kcalPer100g: 120, carbsPer100g: 0, proteinPer100g: 23, fatPer100g: 2.6, fibrePer100g: 0,
                defaultPortionName: "1 portion", defaultPortionGrams: 150,
                isUserCreated: false
            ),

            Food(
                name: "Bacon",
                kcalPer100g: 320, carbsPer100g: 1, proteinPer100g: 20, fatPer100g: 27, fibrePer100g: 0,
                defaultPortionName: "2 rashers", defaultPortionGrams: 60,
                isUserCreated: false
            ),
            
            Food(
                name: "Sausages",
                kcalPer100g: 283, carbsPer100g: 1, proteinPer100g: 20, fatPer100g: 22, fibrePer100g: 0,
                defaultPortionName: "2 Sausages", defaultPortionGrams: 110,
                isUserCreated: false
            ),
            
            Food(
                name: "Baked Beans",
                kcalPer100g: 90, carbsPer100g: 13.2, proteinPer100g: 4.6, fatPer100g: 0.4, fibrePer100g: 5.0,
                defaultPortionName: "half tin", defaultPortionGrams: 200,
                isUserCreated: false
            ),
            
            Food(
                name: "Egg",
                kcalPer100g: 143, carbsPer100g: 1.1, proteinPer100g: 13, fatPer100g: 10, fibrePer100g: 0,
                defaultPortionName: "1 egg", defaultPortionGrams: 60,
                isUserCreated: false
            ),

            Food(
                name: "Cheddar cheese",
                kcalPer100g: 403, carbsPer100g: 1.3, proteinPer100g: 25, fatPer100g: 33, fibrePer100g: 0,
                defaultPortionName: "1 slice", defaultPortionGrams: 30,
                isUserCreated: false
            ),

            Food(
                name: "Yogurt (Greek)",
                kcalPer100g: 120, carbsPer100g: 4, proteinPer100g: 10, fatPer100g: 6, fibrePer100g: 0,
                defaultPortionName: "1 pot", defaultPortionGrams: 150,
                isUserCreated: false
            ),

            Food(
                name: "Milk (semi-skimmed)",
                kcalPer100g: 46, carbsPer100g: 4.8, proteinPer100g: 3.5, fatPer100g: 1.5, fibrePer100g: 0,
                defaultPortionName: "200ml", defaultPortionGrams: 200,
                isUserCreated: false
            ),

            Food(
                name: "Butter",
                kcalPer100g: 717, carbsPer100g: 0.1, proteinPer100g: 0.9, fatPer100g: 81, fibrePer100g: 0,
                defaultPortionName: "1 knob", defaultPortionGrams: 10,
                isUserCreated: false
            ),

            Food(
                name: "Yogurt (plain)",
                kcalPer100g: 60, carbsPer100g: 4.7, proteinPer100g: 3.5, fatPer100g: 3, fibrePer100g: 0,
                defaultPortionName: "1 pot", defaultPortionGrams: 150,
                isUserCreated: false
            ),

            Food(
                name: "Cream",
                kcalPer100g: 340, carbsPer100g: 3, proteinPer100g: 2, fatPer100g: 36, fibrePer100g: 0,
                defaultPortionName: "1 tbsp", defaultPortionGrams: 15,
                isUserCreated: false
            ),

            Food(
                name: "Peanut butter",
                kcalPer100g: 588, carbsPer100g: 20, proteinPer100g: 25, fatPer100g: 50, fibrePer100g: 6,
                defaultPortionName: "1 tbsp", defaultPortionGrams: 15,
                isUserCreated: false
            ),

            // --- Fruit ---
            Food(
                name: "Banana",
                kcalPer100g: 89, carbsPer100g: 23, proteinPer100g: 1.1, fatPer100g: 0.3, fibrePer100g: 2.6,
                defaultPortionName: "1 banana", defaultPortionGrams: 120,
                isUserCreated: false
            ),

            Food(
                name: "Apple",
                kcalPer100g: 52, carbsPer100g: 14, proteinPer100g: 0.3, fatPer100g: 0.2, fibrePer100g: 2.4,
                defaultPortionName: "1 apple", defaultPortionGrams: 180,
                isUserCreated: false
            ),

            Food(
                name: "Orange",
                kcalPer100g: 47, carbsPer100g: 12, proteinPer100g: 0.9, fatPer100g: 0.1, fibrePer100g: 2.4,
                defaultPortionName: "1 orange", defaultPortionGrams: 160,
                isUserCreated: false
            ),

            Food(
                name: "Satsuma",
                kcalPer100g: 53, carbsPer100g: 13, proteinPer100g: 0.8, fatPer100g: 0.3, fibrePer100g: 1.8,
                defaultPortionName: "1 satsuma", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Grapes",
                kcalPer100g: 69, carbsPer100g: 18, proteinPer100g: 0.7, fatPer100g: 0.2, fibrePer100g: 0.9,
                defaultPortionName: "1 handful", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Kiwi",
                kcalPer100g: 61, carbsPer100g: 15, proteinPer100g: 1.1, fatPer100g: 0.5, fibrePer100g: 3,
                defaultPortionName: "1 kiwi", defaultPortionGrams: 75,
                isUserCreated: false
            ),

            Food(
                name: "Mango",
                kcalPer100g: 60, carbsPer100g: 15, proteinPer100g: 0.8, fatPer100g: 0.4, fibrePer100g: 1.6,
                defaultPortionName: "1 cup", defaultPortionGrams: 165,
                isUserCreated: false
            ),

            Food(
                name: "Strawberries",
                kcalPer100g: 32, carbsPer100g: 7.7, proteinPer100g: 0.7, fatPer100g: 0.3, fibrePer100g: 2,
                defaultPortionName: "1 handful", defaultPortionGrams: 100,
                isUserCreated: false
            ),

            Food(
                name: "Blueberries",
                kcalPer100g: 57, carbsPer100g: 14, proteinPer100g: 0.7, fatPer100g: 0.3, fibrePer100g: 2.4,
                defaultPortionName: "1 handful", defaultPortionGrams: 80,
                isUserCreated: false
            ),

            Food(
                name: "Pineapple",
                kcalPer100g: 50, carbsPer100g: 13, proteinPer100g: 0.5, fatPer100g: 0.1, fibrePer100g: 1.4,
                defaultPortionName: "1 cup", defaultPortionGrams: 165,
                isUserCreated: false
            ),

            Food(
                name: "Pear",
                kcalPer100g: 57, carbsPer100g: 15, proteinPer100g: 0.4, fatPer100g: 0.1, fibrePer100g: 3.1,
                defaultPortionName: "1 pear", defaultPortionGrams: 180,
                isUserCreated: false
            )
        ]

        var didInsert = false

        for food in seeds {
            let key = food.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if existingNames.contains(key) { continue }
            ctx.insert(food)
            existingNames.insert(key)
            didInsert = true
        }

        if didInsert {
            try? ctx.save()
        }
    }
}
