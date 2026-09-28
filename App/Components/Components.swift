import SwiftUI
import FootMobKit

/// Team logo with a colored monogram fallback while loading or offline.
struct TeamLogo: View {
    let team: Team
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: team.logoURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Monogram(team: team)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(team.displayName)
    }
}

struct Monogram: View {
    let team: Team

    var body: some View {
        Circle()
            .fill(team.primaryColor.gradient)
            .overlay {
                Text(team.abbreviation)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .padding(2)
            }
    }
}

/// Pulsing red dot used wherever a game is in progress.
struct LiveDot: View {
    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 7))
            .foregroundStyle(.red)
            .symbolEffect(.pulse, options: .repeating)
            .accessibilityHidden(true)
    }
}

struct RankBadge: View {
    let rank: Int?

    var body: some View {
        if let rank {
            Text("\(rank)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// A Liquid Glass surface for grouped content.
struct GlassCard<Content: View>: View {
    var tint: Color?
    var cornerRadius: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.25)) } ?? .regular,
                         in: .rect(cornerRadius: cornerRadius))
    }
}

struct SectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(.tint) }
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

/// Team-color mesh background used behind game and team headers.
struct TeamMeshBackground: View {
    let leading: Color
    let trailing: Color

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                leading, leading.mix(with: trailing, by: 0.5), trailing,
                leading.opacity(0.8), .black.opacity(0.4), trailing.opacity(0.8),
                .black.opacity(0.6), .black.opacity(0.7), .black.opacity(0.6)
            ]
        )
    }
}

enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await retry() } }
                .buttonStyle(.glassProminent)
        }
    }
}
