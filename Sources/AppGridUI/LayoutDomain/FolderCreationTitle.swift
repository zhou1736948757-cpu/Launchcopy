import Foundation

/// Pure category-based suggestion for a newly accepted app-on-app folder creation.
/// Uses committed categories and localized labels; app names and aliases are not inputs.
public enum FolderCreationTitle {
    /// The stationary target supplies the first recognized, usable category label.
    /// Otherwise try the source category, then a neutral localized fallback.
    /// Strings are literal text, never format or localization keys.
    public static func make(
        targetCategory: AppLibraryCategory?,
        sourceCategory: AppLibraryCategory?,
        categoryTitles: [AppLibraryCategory: String],
        fallbackTitle: String,
        existingTitles: [String]
    ) -> String {
        func label(for category: AppLibraryCategory?) -> String? {
            guard let category, category != .other else { return nil }
            return categoryTitles[category].flatMap(usableTitle)
        }
        let base = label(for: targetCategory) ?? label(for: sourceCategory)
            ?? usableTitle(fallbackTitle) ?? "Apps"

        // Normalize comparison copies only; saved user titles stay untouched.
        let occupied = Set(existingTitles.compactMap(usableTitle).map(comparisonKey))
        var candidate = base
        var number = 2
        // At most N suffix candidates can be occupied by N distinct saved titles.
        while occupied.contains(comparisonKey(candidate)) {
            let suffix = " \(number)"
            let stem = String(base.prefix(FolderTitle.maxLength - suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            candidate = stem + suffix
            number += 1
        }
        return candidate
    }

    private static let comparisonLocale = Locale(identifier: "en_US_POSIX")

    private static func comparisonKey(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: comparisonLocale)
    }

    private static func usableTitle(_ raw: String) -> String? {
        let title = FolderTitle.normalized(singleLine(raw), fallback: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.unicodeScalars.contains(where: isMeaningful) else { return nil }
        return title
    }

    /// Collapse whitespace/control runs into one space and remove unsafe format controls.
    /// Preserve script joiners, variation marks and emoji tags instead of stripping all Cf.
    private static func singleLine(_ raw: String) -> String {
        var result = ""
        var previousWasSpace = false
        for scalar in raw.unicodeScalars {
            let category = scalar.properties.generalCategory
            if category == .format && !isPreservedFormat(scalar) { continue }
            if category == .control || category == .lineSeparator || category == .paragraphSeparator
                || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !previousWasSpace { result.append(" ") }
                previousWasSpace = true
            } else {
                result.unicodeScalars.append(scalar)
                previousWasSpace = false
            }
        }
        return result
    }

    private static func isPreservedFormat(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x200C, 0x200D, 0xE0020...0xE007F:
            return true // ZWNJ, ZWJ and subdivision-flag emoji tags.
        default:
            return false
        }
    }

    private static func isMeaningful(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .spaceSeparator, .lineSeparator, .paragraphSeparator,
             .nonspacingMark, .spacingMark, .enclosingMark, .unassigned:
            return false
        default:
            return true
        }
    }
}
