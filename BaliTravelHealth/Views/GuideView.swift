import SwiftUI

struct GuideView: View {
    @State private var selection: Guide?

    private let guides = Guide.placeholders

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                guideList
                Color.clear.frame(height: 100) // breathing room above floating tab bar
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .navigationDestination(item: $selection) { guide in
            GuideDetailPlaceholder(guide: guide)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            // Yellow → background fade so the list flows naturally underneath
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.96, blue: 0.13),
                    Color(red: 1.00, green: 0.96, blue: 0.13),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 60)
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 130, weight: .regular))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Text("Emergency guide")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: 380)
    }

    // MARK: - List

    private var guideList: some View {
        VStack(spacing: 0) {
            ForEach(Array(guides.enumerated()), id: \.element.id) { index, guide in
                Button {
                    selection = guide
                } label: {
                    row(for: guide)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(guide.title)
                .accessibilityHint(guide.summary)
                .accessibilityAddTraits(.isButton)

                if index < guides.count - 1 {
                    Divider()
                        .padding(.leading, 116) // align to text start
                }
            }
        }
    }

    private func row(for guide: Guide) -> some View {
        HStack(spacing: 16) {
            thumbnail(for: guide)
            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Text(guide.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
    }

    private func thumbnail(for guide: Guide) -> some View {
        Group {
            if let name = guide.imageName, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: guide.symbolName)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Detail placeholder

struct GuideDetailPlaceholder: View {
    let guide: Guide

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: guide.symbolName)
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text(guide.title)
                        .font(.title.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(guide.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                Text("Step-by-step content coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 12)

                Spacer(minLength: 40)
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { GuideView() }
}
