// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Stands in for the graph file when its module is missing (see
// PopupGraphFailSmoke.qml): the import cannot be resolved.

import QtQuick
// The module does not exist on purpose: the scene needs a load error
import org.kde.netspeeder.missingcharts // qmllint disable import

Item {
}
