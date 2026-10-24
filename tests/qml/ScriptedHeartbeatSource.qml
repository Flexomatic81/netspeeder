// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The real SensorSource with a heartbeat the test drives (see
// HeartbeatSmoke.qml): the heartbeat sensor counts as missing, the start-up
// probe ends after one second, and every beat() is one sign of life.

import QtQuick
import "../../package/contents/ui/data"

SensorSource {
    id: root

    heartbeatValue: undefined
    heartbeatSensorReady: false
    heartbeatProbeMs: 1000

    function beat() {
        root.heartbeatValue = root.heartbeatValue === undefined ? 1 : root.heartbeatValue + 1;
    }
}
