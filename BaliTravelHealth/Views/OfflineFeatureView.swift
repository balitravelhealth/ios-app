import SwiftUI

/// Full-screen unavailable state shown for features that require a live server
/// connection when the device is offline.
struct OfflineFeatureView: View {
    /// Short name of the unavailable feature, e.g. "Pre-Travel".
    let featureName: String
    /// Describe what the user can try (optional).
    var suggestion: String = "Connect to the internet to access this feature."

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color(.systemGray3))

            Text("You're Offline")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(.label))

            Text("\(featureName) requires an internet connection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(suggestion)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

/// A slim banner to embed inside a scrolling view when only part of the
/// feature needs network (e.g. submit button is disabled while offline).
struct OfflineNoticeBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("You're offline — submission unavailable")
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.55, green: 0.55, blue: 0.58))
    }
}

#Preview("Full") {
    OfflineFeatureView(featureName: "Pre-Travel")
}

#Preview("Banner") {
    OfflineNoticeBanner()
}
