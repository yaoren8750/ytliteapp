import Foundation

/// Content language (`hl`) and region (`gl`) for Innertube requests.
/// Injected into `Core/API` via `ServiceContainer`/`AppDependencies`;
/// Phase 2 of the localization plan points `InnertubeContexts` here
/// instead of its hardcoded `"en"`/`"US"` literals. Features never read
/// this directly.
protocol LocalePreferences {
    var hl: String { get }
    var gl: String { get }
}

/// UserDefaults-backed preferences: content language defaults to the SYSTEM
/// language (not the clamped UI language — YouTube localizes content for
/// far more languages than the app ships UI strings for), region to the
/// device region.
struct DefaultLocalePreferences: LocalePreferences {
    var hl: String {
        if let stored = UserDefaults.standard.string(
            forKey: UserDefaultsKeys.Localization.contentLanguage
        ) {
            return stored
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return String(preferred.prefix(2))
    }

    var gl: String {
        UserDefaults.standard.string(
            forKey: UserDefaultsKeys.Localization.region
        ) ?? Locale.current.regionCode ?? "US"
    }
}
