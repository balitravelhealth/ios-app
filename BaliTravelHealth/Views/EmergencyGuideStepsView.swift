import SwiftUI

struct EmergencyGuideStepsView: View {
    let kategori: String
    let title: String

    @State private var service = EmergencyGuideAPIService.shared
    @Environment(\.openURL) private var openURL

    private var steps: [EmergencyGuideStep] {
        service.steps
            .filter { $0.kategori == kategori }
            .sorted { $0.langkah < $1.langkah }
    }

    var body: some View {
        Group {
            if service.isLoading && steps.isEmpty {
                loadingView
            } else if let error = service.lastError, steps.isEmpty {
                errorView(message: error)
            } else if steps.isEmpty {
                emptyView
            } else {
                stepList
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if service.steps.isEmpty {
                await service.fetchSteps()
            }
        }
    }

    private var stepList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepCard(step: step, index: index)
                }
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func stepCard(step: EmergencyGuideStep, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                stepBadge(number: step.langkah)

                VStack(alignment: .leading, spacing: 8) {
                    if let judul = step.isiMedia?.judul {
                        TranslatingText(judul)
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                    }
                    if let teks = step.isiMedia?.teks, !teks.isEmpty {
                        TranslatingText(teks)
                            .font(.subheadline)
                            .foregroundStyle(Color(.label).opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    metricPills(for: step)

                    if let nomor = step.isiMedia?.nomorDarurat ?? step.isiMedia?.nomor {
                        emergencyCallButton(number: nomor)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(18)

            if index < steps.count - 1 {
                connector
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, index < steps.count - 1 ? 0 : 0)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func metricPills(for step: EmergencyGuideStep) -> some View {
        let pills = buildPills(step: step)
        if !pills.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(pills, id: \.self) { pill in
                    Text(pill)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color(red: 0.16, green: 0.45, blue: 0.92).opacity(0.12))
                        )
                }
            }
        }
    }

    private func buildPills(step: EmergencyGuideStep) -> [String] {
        var pills: [String] = []
        if let ritme = step.isiMedia?.ritme {
            pills.append(String(localized: "Rhythm: \(ritme)", comment: "CPR rhythm rate metric pill"))
        }
        if let kedalaman = step.isiMedia?.kedalaman {
            pills.append(String(localized: "Depth: \(kedalaman)", comment: "CPR compression depth metric pill"))
        }
        if let rasio = step.isiMedia?.rasio {
            pills.append(String(localized: "Ratio: \(rasio)", comment: "CPR compression-breath ratio metric pill"))
        }
        if let jumlah = step.isiMedia?.jumlah { pills.append("\(jumlah)×") }
        return pills
    }

    private func emergencyCallButton(number: String) -> some View {
        Button {
            let cleaned = number.replacingOccurrences(of: " ", with: "")
            if let url = URL(string: "tel:\(cleaned)") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Call \(number)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(red: 0.91, green: 0.23, blue: 0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call emergency number \(number)")
    }

    private func stepBadge(number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.91, green: 0.23, blue: 0.18))
                .frame(width: 34, height: 34)
            Text("\(number)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    private var connector: some View {
        HStack {
            Rectangle()
                .fill(Color(red: 0.91, green: 0.23, blue: 0.18).opacity(0.3))
                .frame(width: 2)
                .padding(.leading, 16 + 17 - 1)
        }
        .frame(height: 8)
        .background(Color(.systemBackground))
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading guide…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load guide")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await service.fetchSteps() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No steps available")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Simple flow layout for pills

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxHeight = max(maxHeight, y + rowHeight)
        }
        return CGSize(width: width, height: maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
