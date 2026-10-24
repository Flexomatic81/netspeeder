// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Editor for the speed levels of the colour mode "By speed": one row per
// level with its minimum (a number and a unit), its colour and a button to
// remove it. The first level starts at 0 and stays. Shows the levels of
// `value` (JSON, as stored) and sends every change of the user as complete,
// valid JSON through `edited`; it never writes `value` itself.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import "../../code/appearance.mjs" as Appearance
import "../../code/text.mjs" as TextTools

Column {
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

    // The stored levels as JSON.
    property string value

    // The user changed the levels; carries the new list as stored JSON.
    signal edited(string json)

    readonly property int rowCount: levelModel.count

    // The controls, for the smoke scene.
    readonly property alias addButton: addLevelButton

    // The row delegate at `index`, for the smoke scene.
    function row(index: int): Item {
        return levelRepeater.itemAt(index);
    }

    // The levels as the rows show them.
    function rowLevels(): var {
        const list = [];
        for (let i = 0; i < levelModel.count; i++) {
            const level = levelModel.get(i);
            list.push({ min: Appearance.joinBytes(level.amount, level.unit), color: level.levelColor });
        }
        return list;
    }

    // Fills the rows from `value`, but only when they show something else:
    // the echo of an edit leaves the rows (and their focus) alone, a sorted
    // or outside change rebuilds them.
    function load() {
        const levels = Appearance.parseThresholds(root.value);
        if (JSON.stringify(levels) === JSON.stringify(root.rowLevels())) {
            return;
        }
        levelModel.clear();
        for (const level of levels) {
            const bytes = Appearance.splitBytes(level.min);
            levelModel.append({ amount: bytes.value, unit: bytes.unitIndex, levelColor: level.color });
        }
    }

    function send() {
        root.edited(Appearance.serializeThresholds(root.rowLevels()));
    }

    function setAmount(index: int, amount: int) {
        const unit = levelModel.get(index).unit;
        levelModel.setProperty(index, "amount", Math.min(amount, Appearance.unitLimit(unit)));
        root.send();
    }

    // A unit in which the number would be too large sets the number to the
    // limit first, so the level stays valid.
    function setUnit(index: int, unit: int) {
        const amount = levelModel.get(index).amount;
        levelModel.setProperty(index, "amount", Math.min(amount, Appearance.unitLimit(unit)));
        levelModel.setProperty(index, "unit", unit);
        root.send();
    }

    function setColor(index: int, color: string) {
        levelModel.setProperty(index, "levelColor", color);
        root.send();
    }

    function removeLevel(index: int) {
        levelModel.remove(index);
        root.send();
    }

    function addLevel() {
        const bytes = Appearance.splitBytes(Appearance.newLevelMin(root.rowLevels()));
        levelModel.append({ amount: bytes.value, unit: bytes.unitIndex, levelColor: "" });
        root.send();
    }

    spacing: Kirigami.Units.smallSpacing

    onValueChanged: root.load()
    Component.onCompleted: root.load()

    ListModel {
        id: levelModel
    }

    Repeater {
        id: levelRepeater

        model: levelModel

        delegate: RowLayout {
            id: levelRow

            required property int index
            required property int amount
            required property int unit
            required property string levelColor

            readonly property bool first: levelRow.index === 0

            // The controls, for the smoke scene.
            readonly property alias numberBox: amountBox
            readonly property alias unitBox: unitChoice
            readonly property alias colorButton: levelColorButton
            readonly property alias themeButton: levelThemeButton
            readonly property alias removeButton: removeLevelButton

            spacing: Kirigami.Units.smallSpacing

            // Typed numbers need more than the arrows: a level can be any
            // number of bytes.
            QQC2.SpinBox {
                id: amountBox

                editable: true
                enabled: !levelRow.first
                from: levelRow.first ? 0 : 1
                to: levelRow.first ? 0 : Appearance.unitLimit(levelRow.unit)
                value: levelRow.amount
                onValueModified: root.setAmount(levelRow.index, amountBox.value)
            }

            ConfigComboBox {
                id: unitChoice

                enabled: !levelRow.first
                options: Appearance.BYTE_UNITS.map((text, index) => ({ text: text, value: index }))
                configValue: levelRow.unit
                onPicked: value => root.setUnit(levelRow.index, value)
            }

            KQuickControls.ColorButton {
                id: levelColorButton

                showAlphaChannel: false
                dialogTitle: root.tr("Choose a colour")
                color: levelRow.levelColor !== "" ? levelRow.levelColor : Kirigami.Theme.textColor
                onAccepted: chosen => root.setColor(levelRow.index, Appearance.toHexColor(chosen.r, chosen.g, chosen.b))
            }

            QQC2.Button {
                id: levelThemeButton

                text: root.trc("@action:button use the colour of the theme", "Theme")
                enabled: levelRow.levelColor !== ""
                onClicked: root.setColor(levelRow.index, "")
            }

            QQC2.ToolButton {
                id: removeLevelButton

                text: root.tr("Remove level")
                icon.name: "list-remove"
                display: QQC2.AbstractButton.IconOnly
                enabled: !levelRow.first
                QQC2.ToolTip.text: removeLevelButton.text
                QQC2.ToolTip.visible: removeLevelButton.hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: root.removeLevel(levelRow.index)
            }
        }
    }

    QQC2.Button {
        id: addLevelButton

        text: root.tr("Add level")
        icon.name: "list-add"
        enabled: levelModel.count < Appearance.MAX_LEVELS
        onClicked: root.addLevel()
    }
}
