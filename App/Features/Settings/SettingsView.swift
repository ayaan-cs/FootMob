import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Appearance", systemImage: "paintpalette.fill").font(.headline)
                            GlassEffectContainer(spacing: 10) {
                                HStack(spacing: 10) {
                                    ForEach(AppearancePreference.allCases) { option in
                                        AppearanceOption(option: option, isSelected: appearance == option) {
                                            withAnimation(.smooth) { appearance = option }
                                        }
                                    }
                                }
                            }
                            Text("Widgets and Live Activities follow your iPhone's setting.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        GlassCard {
                            HStack {
                                Label("About & Credits", systemImage: "info.circle.fill").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .appBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: appearance)
    }
}

/// A tappable mini-preview of each appearance.
private struct AppearanceOption: View {
    let option: AppearancePreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 64)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor : .secondary.opacity(0.3),
                                          lineWidth: isSelected ? 2.5 : 1)
                    }
                Label(option.title, systemImage: option.symbolName)
                    .font(.caption.weight(isSelected ? .bold : .medium))
                    .labelStyle(.titleAndIcon)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(.accentColor.opacity(0.2)).interactive() : .regular.interactive(),
                     in: .rect(cornerRadius: 18))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var preview: some View {
        switch option {
        case .light: sample(background: .white, card: Color(white: 0.92), text: .black)
        case .dark: sample(background: Color(red: 0.02, green: 0.047, blue: 0.098), card: Color(white: 0.16), text: .white)
        case .system:
            HStack(spacing: 0) {
                sample(background: .white, card: Color(white: 0.92), text: .black)
                sample(background: Color(red: 0.02, green: 0.047, blue: 0.098), card: Color(white: 0.16), text: .white)
            }
        }
    }

    private func sample(background: Color, card: Color, text: Color) -> some View {
        ZStack {
            background
            VStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(card)
                        .frame(height: 14)
                        .overlay(alignment: .leading) {
                            Capsule().fill(text.opacity(0.6)).frame(width: 18, height: 3).padding(.leading, 5)
                        }
                }
            }
            .padding(8)
        }
    }
}

#Preview {
    SettingsView()
}
