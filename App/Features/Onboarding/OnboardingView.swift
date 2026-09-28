import SwiftUI
import FootMobKit

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0

    var body: some View {
        ZStack {
            TeamMeshBackground(leading: .blue, trailing: .orange).ignoresSafeArea()

            VStack(spacing: 24) {
                if step == 0 {
                    welcome.transition(.blurReplace)
                } else {
                    TeamPickerView().transition(.blurReplace)
                    Button {
                        model.completeOnboarding()
                    } label: {
                        Text(model.favorites.isEmpty ? "Skip for now" : "Let's go")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .animation(.smooth, value: step)
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "football.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white)
                .frame(width: 140, height: 140)
                .glassEffect(.regular.tint(.white.opacity(0.1)), in: .circle)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text("FootMob").font(.largeTitle.bold()).foregroundStyle(.white)
            Text("Live scores, stats, tables and news for the NFL and college football.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 32)
            VStack(alignment: .leading, spacing: 14) {
                feature("bolt.fill", "Live scores & play-by-play")
                feature("iphone.badge.play", "Live Activities & Dynamic Island")
                feature("square.grid.2x2.fill", "Home & Lock Screen widgets")
                feature("sparkles", "On-device AI news briefings")
            }
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 24)
            Spacer()
            Button {
                step = 1
            } label: {
                Text("Pick your teams").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
        }
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
    }
}
