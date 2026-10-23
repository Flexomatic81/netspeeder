// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Default data source: reads ksystemstats through the sensors module, so no
// process is started per update. Implements the source interface shared with
// ProcSource.qml.

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.ksysguard.sensors as Sensors
import "../../code/procnetdev.mjs" as Procnetdev
import "../../code/sensors.mjs" as SensorCode

Item {
    id: root

    // Sampling interval in milliseconds.
    property int interval: 1000
    property bool running: true
    // True while at least one network interface is known.
    readonly property bool available: internals.interfaceNames.length > 0

    // sample: { timestamp, source, interfaces } as built by buildSensorSample().
    signal sampleReady(var sample)
    // Part of the shared source interface. Never emitted here: a stalled
    // ksystemstats shows up as missing samples, which the provider treats as
    // stale data.
    signal failed(string message)

    // Sensor IDs of all per-interface sensors in use, e.g.
    // "network/enp7s0/download". Lets tests check the IDs the delegates built.
    function activeSensorIds() {
        const ids = [];
        for (let i = 0; i < instances.count; i++) {
            const delegate = internals.delegateAt(i);
            if (delegate === null) {
                continue;
            }
            for (const field of SensorCode.SENSOR_FIELDS) {
                ids.push(delegate.sensorsByField[field].sensorId);
            }
        }
        return ids;
    }

    QtObject {
        id: internals

        // Names of the interfaces ksystemstats offers, in order of discovery.
        property var interfaceNames: []
        // Names of hardware-backed interfaces; null until the device query
        // has answered or when it failed (then every interface counts as
        // physical).
        property var physical: null
        // Time of the last change of the heartbeat sensor, 0 before the first.
        property double lastHeartbeatAt: 0
        // False once the heartbeat sensor turned out not to exist.
        property bool heartbeatRequired: true

        // objectAt() is typed QObject; the properties of the delegate are only
        // known at runtime, hence the untyped result.
        function delegateAt(index): var {
            return instances.objectAt(index);
        }

        // Appends the sensor IDs of all rows below `parent` that are at most
        // `depth` levels deep. Leaves carry an ID, categories and groups do not.
        function collectSensorIds(parent, depth, ids) {
            const rows = tree.rowCount(parent);
            for (let row = 0; row < rows; row++) {
                const index = tree.index(row, 0, parent);
                const id = tree.data(index, Sensors.SensorTreeModel.SensorId);
                if (typeof id === "string" && id !== "") {
                    ids.push(id);
                }
                if (depth > 1) {
                    internals.collectSensorIds(index, depth - 1, ids);
                }
            }
        }

        // Re-reads the interface list from the sensor tree. Only sensor IDs
        // are used, never the labels, which are translated.
        function rescan() {
            const ids = [];
            // An invalid index stands for the root of the tree.
            internals.collectSensorIds(tree.index(-1, -1), 3, ids);
            const names = SensorCode.interfacesFromSensorIds(ids);
            if (names.join("\n") === internals.interfaceNames.join("\n")) {
                return;
            }
            internals.interfaceNames = names;
            internals.syncModel(names);
            devices.run();
        }

        // Brings the delegate model in line with `names` by removing and
        // appending single rows. Interfaces that stay keep their sensors; a
        // wholesale rebuild would show them with zero values for a moment.
        function syncModel(names) {
            const present = [];
            for (let row = interfaceModel.count - 1; row >= 0; row--) {
                const name = interfaceModel.get(row).interfaceName;
                if (names.indexOf(name) < 0) {
                    interfaceModel.remove(row);
                } else {
                    present.push(name);
                }
            }
            for (const name of names) {
                if (present.indexOf(name) < 0) {
                    interfaceModel.append({ "interfaceName": name });
                }
            }
        }

        function emitSample() {
            const now = Date.now();
            if (internals.heartbeatRequired
                    && !SensorCode.isHeartbeatFresh(internals.lastHeartbeatAt, now, root.interval)) {
                return;
            }
            const values = {};
            for (let i = 0; i < instances.count; i++) {
                const delegate = internals.delegateAt(i);
                if (delegate !== null) {
                    values[delegate.interfaceName] = delegate.readValues();
                }
            }
            // Sent even without interfaces, so that vanished ones leave the display.
            root.sampleReady(SensorCode.buildSensorSample(now, values, internals.physical));
        }
    }

    Sensors.SensorTreeModel {
        id: tree
    }

    // The tree fills up and changes in many small steps; the timer merges them.
    Connections {
        target: tree

        function onRowsInserted() {
            rescanTimer.restart();
        }

        function onRowsRemoved() {
            rescanTimer.restart();
        }

        function onModelReset() {
            rescanTimer.restart();
        }
    }

    Timer {
        id: rescanTimer

        interval: 500
        onTriggered: internals.rescan()
    }

    Component.onCompleted: rescanTimer.start()

    // Tells which interfaces are hardware-backed (kind "physical").
    CommandRunner {
        id: devices

        command: Procnetdev.DEVICES_COMMAND

        onFinished: (exitCode, stdout, stderr) => {
            if (exitCode !== 0) {
                internals.physical = null;
                console.warn("netspeeder: device query failed (exit " + exitCode + "): " + stderr);
                return;
            }
            internals.physical = Procnetdev.parseDeviceList(stdout);
        }
    }

    // One row per known interface; kept in step with internals.interfaceNames
    // by internals.syncModel().
    ListModel {
        id: interfaceModel
    }

    Instantiator {
        id: instances

        model: interfaceModel

        delegate: QtObject {
            id: interfaceDelegate

            // Not called "name": inside a Sensor, an unqualified `name` would
            // resolve to the sensor's own property. Always reach this value
            // through the delegate id.
            required property string interfaceName
            readonly property var sensorsByField: ({
                "download": downloadSensor,
                "upload": uploadSensor,
                "totalDownload": totalDownloadSensor,
                "totalUpload": totalUploadSensor,
                "network": networkSensor,
                "ipv4address": ipv4Sensor,
                "ipv6address": ipv6Sensor,
                "signal": signalSensor
            })

            // Raw values by field name; undefined until the first reading.
            function readValues() {
                const values = {};
                for (const field of SensorCode.SENSOR_FIELDS) {
                    values[field] = interfaceDelegate.sensorsByField[field].value;
                }
                return values;
            }

            property Sensors.Sensor downloadSensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/download"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor uploadSensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/upload"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor totalDownloadSensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/totalDownload"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor totalUploadSensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/totalUpload"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor networkSensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/network"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor ipv4Sensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/ipv4address"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor ipv6Sensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/ipv6address"
                updateRateLimit: root.interval
            }
            property Sensors.Sensor signalSensor: Sensors.Sensor {
                sensorId: "network/" + interfaceDelegate.interfaceName + "/signal"
                updateRateLimit: root.interval
            }
        }
    }

    // libksysguard does not repeat unchanged values, so a quiet network cannot
    // be told from stalled sensors. The system uptime changes every second and
    // serves as the sign of life.
    Sensors.Sensor {
        id: heartbeat

        sensorId: SensorCode.HEARTBEAT_SENSOR
        updateRateLimit: 1000
        onValueChanged: {
            // The sensor also signals once on creation, before it has a value.
            if (heartbeat.value !== undefined) {
                internals.lastHeartbeatAt = Date.now();
            }
        }
    }

    // Without a heartbeat sensor (missing in this Plasma version) the check
    // would block all samples, so it is switched off.
    Timer {
        interval: 10000
        running: true
        onTriggered: {
            if (heartbeat.status !== Sensors.Sensor.Ready) {
                internals.heartbeatRequired = false;
                console.warn("netspeeder: heartbeat sensor " + SensorCode.HEARTBEAT_SENSOR
                    + " unavailable, staleness check disabled");
            }
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.running
        onTriggered: internals.emitSample()
    }
}
