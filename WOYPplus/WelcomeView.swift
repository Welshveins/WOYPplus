import SwiftUI
import UIKit

struct WelcomeView: View {

    let onEnter: () -> Void
    @State private var showingHelp = false

    // Subtle fade
    @State private var contentOpacity: Double = 0
    @State private var contentOffsetY: CGFloat = 8

    // Slower transition
    @State private var isEntering = false

    // Your asset name (as you wrote)
    private let logoAssetName = "WOYPPluslogo"

    var body: some View {
        ZStack {
            Color.woypSlate.opacity(0.15).ignoresSafeArea()

            VStack(spacing: 18) {

                Spacer(minLength: 24)

                // MARK: Logo + Title
                VStack(spacing: 12) {
                    Image(logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .accessibilityHidden(true)

                    Text("WOYP Plus")
                        .font(.system(size: 40, weight: .semibold))
                        .tracking(-0.5)
                }
                .opacity(contentOpacity)
                .offset(y: contentOffsetY)

                Spacer(minLength: 18)

                // MARK: Enter
                Button {
                    guard !isEntering else { return }
                    isEntering = true

                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.prepare()
                    gen.impactOccurred()

                    // Slower / calmer transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        onEnter()
                        isEntering = false
                    }
                } label: {
                    HStack {
                        Text(isEntering ? "Entering…" : "Enter")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.woypSlate.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(isEntering)
                .padding(.horizontal, 24)
                .opacity(contentOpacity)
                .offset(y: contentOffsetY)

                // MARK: Footer help
                Button {
                    showingHelp = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text("Help")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                }
                .buttonStyle(.plain)
                .opacity(contentOpacity)
                .offset(y: contentOffsetY)

                Spacer(minLength: 10)
            }
        }
        .sheet(isPresented: $showingHelp) {
            NavigationStack { HelpInstructionsView() }
        }
        .onAppear {
            contentOpacity = 0
            contentOffsetY = 8
            withAnimation(.easeOut(duration: 0.45)) {
                contentOpacity = 1
                contentOffsetY = 0
            }
        }
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
