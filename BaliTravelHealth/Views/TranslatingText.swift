import SwiftUI

/// Drop-in `Text` replacement for Indonesian backend content.
///
/// All translations are resolved **at launch time** by `AppLaunchCoordinator`
/// before the user can navigate anywhere. This view is a pure synchronous
/// dictionary lookup — zero async, zero flicker, no `translationTask`.
///
/// Fallback: if a string hasn't been translated yet (first launch on iOS < 17.4,
/// or a network error during fetch), the original text is shown unchanged.
struct TranslatingText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let deviceLang = Locale.current.language.languageCode?.identifier ?? "en"
        let display = deviceLang != "id"
            ? (TranslationDictionaryService.shared.lookup(text) ?? text)
            : text
        return Text(display)
    }
}
