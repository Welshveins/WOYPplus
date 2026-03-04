import SwiftUI

struct MacroRingView: View {
    
    var carbs: Double
    var protein: Double
    var fat: Double
    
    /// If true: carbs/protein/fat are fractions (0...1) and should sum to 1.
    /// If false: carbs/protein/fat are grams and will be normalized to fractions.
    var isFractionInput: Bool = false
    
    var lineWidth: CGFloat = 18
    var segmentGap: Double = 0.001               // fraction of circle
    var backgroundOpacity: Double = 0.15
    
    /// ✅ set to .butt for square ends (no rounding)
    var lineCap: CGLineCap = .round
    
    var body: some View {
        
        let fracs = fractions()
        
        ZStack {
            
            // Background ring
            Circle()
                .stroke(
                    Color.secondary.opacity(backgroundOpacity),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap)
                )
            
            // Segments (C -> P -> F), with consistent gap applied to each segment
            ringSegment(from: 0.0, to: fracs.c, color: .woypSand)
            ringSegment(from: fracs.c, to: fracs.c + fracs.p, color: .woypTeal)
            ringSegment(from: fracs.c + fracs.p, to: min(1.0, fracs.c + fracs.p + fracs.f), color: .woypTerracotta)
        }
        .rotationEffect(.degrees(-90))
    }
    
    private func fractions() -> (c: Double, p: Double, f: Double) {
        if isFractionInput {
            let total = max(carbs + protein + fat, 1e-9)
            return (carbs / total, protein / total, fat / total)
        } else {
            let total = max(carbs + protein + fat, 1e-9)
            return (carbs / total, protein / total, fat / total)
        }
    }
    
    @ViewBuilder
    private func ringSegment(from start: Double, to end: Double, color: Color) -> some View {
        
        // Apply half-gap to each end so all gaps are equal
        let g = max(0, segmentGap)
        let s = start + g / 2
        let e = end - g / 2
        
        if e > s {
            Circle()
                .trim(from: s, to: e)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: lineCap,
                        lineJoin: .miter
                    )
                )
        }
        
    }
}
