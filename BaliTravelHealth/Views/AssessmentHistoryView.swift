import SwiftUI

struct AssessmentHistoryView: View {
    @State private var service = AssessmentService.shared

    var body: some View {
        Group {
            if service.isLoading && service.history.isEmpty {
                loadingView
            } else if let error = service.lastError, service.history.isEmpty {
                errorView(message: error)
            } else if service.history.isEmpty {
                emptyView
            } else {
                historyList
            }
        }
        .navigationTitle("Assessment History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.fetchHistory() }
    }

    private var historyList: some View {
        List {
            historySection(
                title: "Pre-Travel",
                systemImage: "airplane.departure",
                results: service.history.filter { $0.kategori == .preTravel }
            )
            historySection(
                title: "Post-Travel",
                systemImage: "airplane.arrival",
                results: service.history.filter { $0.kategori == .postTravel }
            )

            let uncategorized = service.history.filter { $0.kategori == nil }
            if !uncategorized.isEmpty {
                historySection(
                    title: "Uncategorized",
                    systemImage: "questionmark.folder",
                    results: uncategorized
                )
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
        .refreshable { await service.fetchHistory() }
    }

    @ViewBuilder
    private func historySection(title: String, systemImage: String, results: [AssessmentResult]) -> some View {
        if !results.isEmpty {
            Section {
                ForEach(results) { result in
                    AssessmentHistoryRow(result: result)
                }
            } header: {
                Label(title, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading history…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load history")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await service.fetchHistory() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(Color(.systemGray3))
            Text("No assessments yet")
                .font(.title3.weight(.semibold))
            Text("Complete a health risk assessment to see your history here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Row

private struct AssessmentHistoryRow: View {
    let result: AssessmentResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: riskSymbol)
                .font(.system(size: 28))
                .foregroundStyle(riskColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.riskLevel.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(riskColor)
                    Spacer()
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TranslatingText(result.diagnosis)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)
                if let kategori = result.kategori {
                    Text(kategori.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var riskColor: Color {
        switch result.riskLevel {
        case .low:    return Color(red: 0.15, green: 0.65, blue: 0.25)
        case .medium: return Color(red: 0.90, green: 0.55, blue: 0.10)
        case .high:   return Color(red: 0.85, green: 0.18, blue: 0.12)
        case .emergency: return Color(red: 0.72, green: 0.05, blue: 0.10)
        }
    }

    private var riskSymbol: String {
        switch result.riskLevel {
        case .low:    return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high:   return "xmark.shield.fill"
        case .emergency: return "cross.case.fill"
        }
    }

    private var dateString: String {
        let raw = result.assessmentDate ?? result.createdAt ?? ""
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return raw
    }
}

#Preview {
    NavigationStack {
        AssessmentHistoryView()
    }
}
