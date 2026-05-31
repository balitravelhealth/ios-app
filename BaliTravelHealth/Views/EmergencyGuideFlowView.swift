import SwiftUI

struct EmergencyGuideFlowView: View {
    let flowId: Int
    let flowTitle: String

    @State private var service = EmergencyGuideAPIService.shared
    @State private var flow: EmergencyGuideFlowDetail?
    @State private var currentNodeId: String?
    @State private var history: [String] = []
    @State private var isLoadingDetail = false
    @State private var loadError: String?

    private var currentNode: GuideFlowNode? {
        guard let id = currentNodeId else { return nil }
        return flow?.nodes.first { $0.id == id }
    }

    var body: some View {
        Group {
            if isLoadingDetail {
                loadingView
            } else if let error = loadError {
                errorView(message: error)
            } else if let node = currentNode {
                nodeView(node: node)
            } else if flow != nil {
                completedView
            } else {
                loadingView
            }
        }
        .navigationTitle(TranslationDictionaryService.shared.lookup(flowTitle) ?? flowTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !history.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { goBack() }
                }
            }
        }
        .task {
            await loadFlow()
        }
    }

    // MARK: - Node view

    private func nodeView(node: GuideFlowNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                nodeCard(node: node)
                if let choices = node.choices, !choices.isEmpty {
                    choicesSection(choices: choices)
                } else {
                    doneButton
                }
                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func nodeCard(node: GuideFlowNode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.92))
                TranslatingText(node.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.label))
            }
            .accessibilityAddTraits(.isHeader)

            TranslatingText(node.instruction)
                .font(.body)
                .foregroundStyle(Color(.label).opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func choicesSection(choices: [GuideFlowChoice]) -> some View {
        VStack(spacing: 10) {
            Text("What do you observe?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                choiceButton(choice: choice)
            }
        }
    }

    private func choiceButton(choice: GuideFlowChoice) -> some View {
        Button {
            navigate(to: choice.nextId)
        } label: {
            HStack {
                TranslatingText(choice.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(buttonForeground(for: choice.variant))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(buttonForeground(for: choice.variant).opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(buttonBackground(for: choice.variant))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.label)
        .accessibilityAddTraits(.isButton)
    }

    private func buttonBackground(for variant: String) -> Color {
        switch variant {
        case "yes": return Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.15)
        case "no":  return Color(red: 0.91, green: 0.23, blue: 0.18).opacity(0.12)
        default:    return Color(.systemGray5)
        }
    }

    private func buttonForeground(for variant: String) -> Color {
        switch variant {
        case "yes": return Color(red: 0.10, green: 0.60, blue: 0.25)
        case "no":  return Color(red: 0.75, green: 0.15, blue: 0.12)
        default:    return Color(.label)
        }
    }

    private var doneButton: some View {
        Button {
            currentNodeId = nil
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Done")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.78, blue: 0.35))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed / summary view

    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
            Text("Guide Complete")
                .font(.title2.weight(.bold))
            Text("You've reached the end of the guide.\nIf the situation is ongoing, call 119 immediately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Start Over") { restart() }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.16, green: 0.45, blue: 0.92))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - State & loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading guide…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
            Button("Try Again") { Task { await loadFlow() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Navigation

    private func navigate(to nodeId: String?) {
        guard let nodeId else {
            // nil nextId means the guide is done
            if let current = currentNodeId { history.append(current) }
            currentNodeId = nil
            return
        }
        if let current = currentNodeId { history.append(current) }
        withAnimation(.easeInOut(duration: 0.22)) { currentNodeId = nodeId }
    }

    private func goBack() {
        guard let prev = history.popLast() else { return }
        withAnimation(.easeInOut(duration: 0.22)) { currentNodeId = prev }
    }

    private func restart() {
        history.removeAll()
        currentNodeId = flow?.nodes.first { $0.isEntry == true }?.id
    }

    private func loadFlow() async {
        isLoadingDetail = true
        loadError = nil
        defer { isLoadingDetail = false }
        do {
            let detail = try await service.fetchFlowDetail(id: flowId)
            flow = detail
            currentNodeId = detail.nodes.first { $0.isEntry == true }?.id
                ?? detail.nodes.first?.id
        } catch {
            loadError = error.localizedDescription
        }
    }
}
