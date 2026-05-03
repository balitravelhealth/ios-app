import SwiftUI

/// Root tabbed shell. On iOS 26 the standard `TabView` automatically uses the
/// floating Liquid Glass tab bar; on iOS 18 it falls back to the standard
/// material tab bar.
struct MainTabView: View {
    @State private var selection: AppTab = .home

    enum AppTab: Hashable {
        case home, guide, profile
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            liquidGlassTabView
        } else {
            legacyTabView
        }
    }

    // MARK: - iOS 26 Liquid Glass

    @available(iOS 26.0, *)
    private var liquidGlassTabView: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab("Guide", systemImage: "cross.case.fill", value: AppTab.guide) {
                NavigationStack { GuideView() }
            }
            Tab("Profile", systemImage: "person.fill", value: AppTab.profile) {
                NavigationStack { ProfileView() }
            }
        }
        .tint(Color(red: 0.82, green: 0.27, blue: 0.20))   // BTH red
    }

    // MARK: - iOS 18 fallback

    private var legacyTabView: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            NavigationStack { GuideView() }
                .tabItem { Label("Guide", systemImage: "cross.case.fill") }
                .tag(AppTab.guide)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTab.profile)
        }
        .tint(Color(red: 0.82, green: 0.27, blue: 0.20))
    }
}

#Preview {
    MainTabView()
        .environment(AuthenticationManager())
        .environment(ProfileStore())
}
