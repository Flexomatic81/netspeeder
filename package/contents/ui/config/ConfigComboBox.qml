// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The one selection list of the settings pages. The shown entry follows the
// bound setting, and only a choice of the user writes back.
//
//   ConfigComboBox {
//       options: [{ text: "Download first", value: false }, { text: "Upload first", value: true }]
//       configValue: root.cfg_uploadFirst
//       onPicked: value => root.cfg_uploadFirst = value
//   }
//
// The values keep their JS type (boolean, number, string), as the settings are
// typed. Needs no translation: the caller translates the texts.
//
// The index is set by hand, never through a binding `currentIndex:
// indexOfValue(...)`: while the component is being created, such a binding
// finds the wrong index (measured on 2026-10-23). It is set at the end of the
// creation and whenever the setting changes, also from outside, for example by
// the "Defaults" button of the dialog, and when `options` is replaced (which
// resets the list).

import QtQuick
import QtQuick.Controls as QQC2

QQC2.ComboBox {
    id: root

    // Array of { text, value }.
    property var options: []
    // The setting this list shows; bound to the page's cfg_ property.
    property var configValue

    // The user chose an entry; carries its value.
    signal picked(var value)

    function showConfigValue() {
        root.currentIndex = root.indexOfValue(root.configValue);
    }

    model: root.options
    textRole: "text"
    valueRole: "value"
    // Wide enough for the longest entry, not only for the one shown.
    implicitContentWidthPolicy: QQC2.ComboBox.WidestText

    onConfigValueChanged: root.showConfigValue()
    onModelChanged: root.showConfigValue()
    Component.onCompleted: root.showConfigValue()
    // Emitted only for a choice of the user, after currentIndex has moved.
    onActivated: root.picked(root.currentValue)
}
