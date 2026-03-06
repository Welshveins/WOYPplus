import SwiftUI

struct PressableCardStyle: ButtonStyle {

    var cornerRadius: CGFloat = 18
    var baseOpacity: Double = 0.08
    var pressedOpacity: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {

        configuration.label
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.woypSlate.opacity(
                        configuration.isPressed ? pressedOpacity : baseOpacity
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)   // compression
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
