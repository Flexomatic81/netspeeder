// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The pages of the settings dialog. Plasma resolves the sources against
// contents/ui. More pages follow with later releases.

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Display")
        icon: "preferences-desktop-display"
        source: "config/ConfigDisplay.qml"
    }
    ConfigCategory {
        name: i18n("Data")
        icon: "network-wired"
        source: "config/ConfigData.qml"
    }
}
