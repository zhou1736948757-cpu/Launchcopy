import AppGridUI
import LauncherLocalization

/// Presentation-only mapping. Taxonomy and classification remain in AppGridUI.
enum AppLibraryCategoryLabels {
    static func key(for category: AppLibraryCategory) -> LibraryTextKey {
        switch category {
        case .business: return .categoryBusiness
        case .developerTools: return .categoryDeveloperTools
        case .education: return .categoryEducation
        case .entertainment: return .categoryEntertainment
        case .finance: return .categoryFinance
        case .games: return .categoryGames
        case .graphicsDesign: return .categoryGraphicsDesign
        case .healthcareFitness: return .categoryHealthcareFitness
        case .lifestyle: return .categoryLifestyle
        case .medical: return .categoryMedical
        case .music: return .categoryMusic
        case .news: return .categoryNews
        case .photography: return .categoryPhotography
        case .productivity: return .categoryProductivity
        case .reference: return .categoryReference
        case .socialNetworking: return .categorySocialNetworking
        case .sports: return .categorySports
        case .travel: return .categoryTravel
        case .utilities: return .categoryUtilities
        case .video: return .categoryVideo
        case .weather: return .categoryWeather
        case .other: return .categoryOther
        }
    }

    static func title(for category: AppLibraryCategory?, strings: LocalizedStrings) -> String {
        strings.libraryText(category.map { key(for: $0) } ?? .all)
    }
}
