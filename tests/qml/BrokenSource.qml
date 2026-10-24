// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Stands in for the /proc source when it cannot be loaded (see
// ProviderSmoke.qml): the import cannot be resolved.

import QtQuick
// The module does not exist on purpose: the scene needs a load error
import org.kde.netspeeder.missingsource // qmllint disable import

Item {
}
