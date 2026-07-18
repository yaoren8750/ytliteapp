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

/// UserDefaults-backed preferences: content language defaults to the app
/// language ("same as app" — most users touch one setting only), region
/// to the device region.
struct DefaultLocalePreferences: LocalePreferences {
    var hl: String {
        UserDefaults.standard.string(
            forKey: UserDefaultsKeys.Localization.contentLanguage
        ) ?? AppLanguage.effective.rawValue
    }

    var gl: String {
        UserDefaults.standard.string(
            forKey: UserDefaultsKeys.Localization.region
        ) ?? Locale.current.regionCode ?? "US"
    }
}
