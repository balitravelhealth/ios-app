import SwiftUI

struct HealthRiskAssessmentView: View {
    let kategori: AssessmentKategori

    @State private var symptomService = ExpertSymptomService.shared
    @State private var assessmentService = AssessmentService.shared
    @State private var profileStore: ProfileStore?
    @Environment(ProfileStore.self) private var envProfileStore

    @State private var selectedSymptomIds: Set<Int> = []
    @State private var result: AssessmentResult?
    @State private var submitError: String?
    @State private var isSubmitting = false

    var body: some View {
        Group {
            if result != nil {
                resultView
            } else if symptomService.isLoading {
                loadingView(message: "Loading symptom list…")
            } else if symptomService.isUnavailable {
                serviceUnavailableView
            } else if let error = symptomService.lastError {
                errorView(message: error)
            } else {
                assessmentForm
            }
        }
        .navigationTitle(kategori == .preTravel ? "Health Risk Assessment" : "Health Screening")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAssessmentMenu()
        }
    }

    // MARK: - Assessment form

    private var assessmentForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    symptomList
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            submitBar
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kategori == .preTravel
                 ? "Select any symptoms you currently have before your trip."
                 : "Select any symptoms you've experienced since returning from Bali.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !selectedSymptomIds.isEmpty {
                Text("\(selectedSymptomIds.count) symptom\(selectedSymptomIds.count == 1 ? "" : "s") selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
            }
        }
    }

    private var symptomList: some View {
        VStack(spacing: 8) {
            ForEach(symptomService.symptoms) { symptom in
                SymptomRow(
                    label: symptom.primaryDisplayName,
                    sublabel: symptom.secondaryDisplayName,
                    isSelected: selectedSymptomIds.contains(symptom.id)
                ) {
                    toggle(symptom: symptom)
                }
            }
        }
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                if let error = submitError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Submit Assessment")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedSymptomIds.isEmpty
                                  ? Color(.systemGray4)
                                  : Color(red: 0.16, green: 0.45, blue: 0.92))
                    )
                    .foregroundStyle(selectedSymptomIds.isEmpty ? Color(.systemGray2) : .white)
                }
                .buttonStyle(.plain)
                .disabled(selectedSymptomIds.isEmpty || isSubmitting)
                .accessibilityLabel("Submit assessment")
                .accessibilityHint(selectedSymptomIds.isEmpty ? "Select at least one symptom" : "Submits your selected symptoms")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Result view

    private var resultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                resultHeader
                if let r = result {
                    resultCard(r)
                }

                Button {
                    result = nil
                    selectedSymptomIds = []
                    submitError = nil
                } label: {
                    Label("Submit Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.16, green: 0.45, blue: 0.92))
                .accessibilityHint("Start a new health risk assessment")

                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Latest Expert System Result")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(.label))
            Text("Your submitted symptoms have been analyzed by the BaliTravelHealth expert system.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func resultCard(_ r: AssessmentResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: riskSymbol(r.riskLevel))
                    .font(.title.weight(.semibold))
                    .foregroundStyle(riskColor(r.riskLevel))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(riskColor(r.riskLevel).opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(r.riskLevel.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(riskColor(r.riskLevel))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnosis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TranslatingText(r.diagnosis)
                    .font(.body)
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !r.recommendation.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TranslatingText(r.recommendation)
                        .font(.body)
                        .foregroundStyle(Color(.label))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            let pct = Int((r.confidenceScore * 100).rounded())
            HStack {
                Text("Confidence score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pct)%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Placeholder states

    private func loadingView(message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var serviceUnavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "stethoscope.circle")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color(.systemGray3))
            Text("Symptom Catalog Unavailable")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("The symptom list is temporarily unavailable.\nPlease try again later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await symptomService.fetch(kategori: kategori) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.16, green: 0.45, blue: 0.92))
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load symptoms")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await symptomService.fetch(kategori: kategori) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func loadAssessmentMenu() async {
        if result == nil, let latestResult = assessmentService.latestResult {
            result = latestResult
        }

        await assessmentService.fetchHistory(page: 1, limit: 1)
        if result == nil, let latestHistoryResult = assessmentService.history.first {
            result = latestHistoryResult
        }

        symptomService.reset()
        await symptomService.fetch(kategori: kategori)
    }

    private func toggle(symptom: ExpertSymptom) {
        if selectedSymptomIds.contains(symptom.id) {
            selectedSymptomIds.remove(symptom.id)
        } else {
            selectedSymptomIds.insert(symptom.id)
        }
    }

    private func submit() async {
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            let submitted = try await assessmentService.submit(
                symptoms: Array(selectedSymptomIds),
                kategori: kategori
            )
            result = submitted
            envProfileStore.setHealthRiskAssessmentCompleted(true)
        } catch BaliAPIError.unavailable {
            submitError = "Diagnosis service is temporarily unavailable. Please try again later."
        } catch {
            submitError = error.localizedDescription
        }
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low:    return Color(red: 0.15, green: 0.65, blue: 0.25)
        case .medium: return Color(red: 0.90, green: 0.55, blue: 0.10)
        case .high:   return Color(red: 0.85, green: 0.18, blue: 0.12)
        case .emergency: return Color(red: 0.72, green: 0.05, blue: 0.10)
        }
    }

    private func riskSymbol(_ level: RiskLevel) -> String {
        switch level {
        case .low:    return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high:   return "xmark.shield.fill"
        case .emergency: return "cross.case.fill"
        }
    }
}

// MARK: - Symptom row

private struct SymptomRow: View {
    let label: String
    let sublabel: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isSelected
                        ? Color(red: 0.16, green: 0.45, blue: 0.92)
                        : Color(.systemGray3)
                    )
                    .animation(.easeInOut(duration: 0.15), value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.label))
                        .fixedSize(horizontal: false, vertical: true)
                    if let sublabel {
                        Text(sublabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected
                          ? Color(red: 0.16, green: 0.45, blue: 0.92).opacity(0.08)
                          : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color(red: 0.16, green: 0.45, blue: 0.92).opacity(0.4)
                        : Color(.separator).opacity(0.3),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sublabel.map { "\(label), \($0)" } ?? label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    NavigationStack {
        HealthRiskAssessmentView(kategori: .preTravel)
            .environment(ProfileStore())
    }
}
