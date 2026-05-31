import Foundation

/// In-memory + on-disk cache of Indonesian → device-language translations.
///
/// Translations are saved to `LocalDataCache` as a JSON dictionary keyed by the
/// target language code (e.g. `translation_cache_id_to_en.json`).
///
/// Flow:
/// 1. `AppLaunchCoordinator` calls `load()` once at startup — O(1) file read.
/// 2. `TranslatingText` calls `lookup(_:)` synchronously — O(1) dictionary lookup.
/// 3. On a cache miss `TranslatingText` fires `translationTask`; when it completes
///    it calls `store(_:translated:)` which writes to memory and schedules a disk flush.
@MainActor
@Observable
final class TranslationDictionaryService {
    static let shared = TranslationDictionaryService()

    /// In-memory store: source (Indonesian) → translated text.
    private(set) var translations: [String: String] = [:]
    private var isLoaded = false

    /// Current target language code (e.g. "en", "fr"). Derived from device locale.
    private var targetLang: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    // MARK: - Load

    /// Call once at app launch to warm the in-memory cache from disk.
    func load() async {
        guard !isLoaded else { return }
        isLoaded = true
        if let saved = try? await LocalDataCache.shared.loadTranslations(targetLang: targetLang) {
            translations = saved
        }
    }

    // MARK: - Lookup (synchronous — call from SwiftUI init or task)

    /// Returns the cached translation for `indonesian`, or `nil` on a cache miss.
    func lookup(_ indonesian: String) -> String? {
        translations[indonesian]
    }

    // MARK: - Store

    /// Saves a single source→translated pair and flushes to disk.
    func store(_ source: String, translated: String) async {
        await storeBatch([source: translated])
    }

    /// Saves a batch of source→translated pairs in one disk write.
    func storeBatch(_ dict: [String: String]) async {
        var changed = false
        for (source, translated) in dict {
            guard !source.isEmpty, !translated.isEmpty, source != translated else { continue }
            translations[source] = translated
            changed = true
        }
        guard changed else { return }
        // Capture value types before crossing actor boundaries
        let snapshot = translations
        let lang = targetLang
        Task.detached(priority: .utility) {
            try? await LocalDataCache.shared.saveTranslations(snapshot, targetLang: lang)
        }
    }
}
