// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The pages of the settings dialog. Plasma resolves the sources against
// contents/ui. More pages follow with later releases.

import org.kde.plasma.configuration
import "../code/text.mjs" as TextTools

ConfigModel {
    id: root

    // Translation helpers: the only place that calls Plasma's i18n functions.
    // Plain qml6 (the smoke scenes) has none and gets the English text.
    function tr(text: string, ...args): string {
        // Plasma context function, not declared for qmllint
        return typeof i18n === "function" ? i18n(text, ...args) : TextTools.substitute(text, args); // qmllint disable unqualified
    }
    function trc(context: string, text: string, ...args): string {
        // Plasma context function, not declared for qmllint
        return typeof i18nc === "function" ? i18nc(context, text, ...args) : TextTools.substitute(text, args); // qmllint disable unqualified
    }
    function trp(singular: string, plural: string, n: int, ...args): string {
        // Plasma context function, not declared for qmllint
        return typeof i18np === "function" ? i18np(singular, plural, n, ...args) : TextTools.pluralFallback(singular, plural, n, args); // qmllint disable unqualified
    }

    ConfigCategory {
        name: root.tr("Display")
        icon: "preferences-desktop-display"
        source: "config/ConfigDisplay.qml"
    }
    ConfigCategory {
        name: root.tr("Data")
        icon: "network-wired"
        source: "config/ConfigData.qml"
    }
}
