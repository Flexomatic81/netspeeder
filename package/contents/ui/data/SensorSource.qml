// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Default data source: reads ksystemstats through the sensors module, so no
// process is started per update. Implements the source interface shared with
// ProcSource.qml.

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.ksysguard.sensors as Sensors
import "../../code/listsync.mjs" as ListSync
import "../../code/procnetdev.mjs" as Procnetdev
import "../../code/sensors.mjs" as SensorCode

Item {
    id: root

    // Sampling interval in milliseconds.
    property int interval: 1000
    property bool running: true
    // True while at least one network interface is known.
    readonly property bool available: internals.interfaceNames.length > 0

    // Test seams: the sign of life, whether its sensor exists, and how long
    // the start-up probe waits before it decides that the sensor is missing.
    // Bound to the heartbeat sensor below; tests replace them to play a sensor
    // service that starts late or stops.
    property var heartbeatValue: heartbeat.value
    property bool heartbeatSensorReady: heartbeat.status === Sensors.Sensor.Ready
    property int heartbeatProbeMs: 10000

    // The sensor also signals once on creation, before it has a value.
    onHeartbeatValueChanged: {
        if (root.heartbeatValue !== undefined) {
            internals.updateGate({ type: "heartbeat", now: Date.now(), value: root.heartbeatValue });
        }
    }

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
        // Names of the other present interfaces, from the same query; also
        // those ksystemstats does not offer (null like `physical`).
        property var virtualNames: null
        // Whether samples need a fresh heartbeat, and when the last one came;
        // see heartbeatGate() in sensors.mjs.
        property var heartbeatGate: SensorCode.initialHeartbeatGate()

        // Applies a heartbeat event and logs when the check goes off or on.
        function updateGate(event) {
            const next = SensorCode.heartbeatGate(internals.heartbeatGate, event);
            if (next.required !== internals.heartbeatGate.required) {
                console.warn("netspeeder: heartbeat sensor " + SensorCode.HEARTBEAT_SENSOR
                    + (next.required ? " is back, staleness check enabled"
                                     : " unavailable, staleness check disabled"));
            }
            internals.heartbeatGate = next;
        }

        // objectAt() is typed QObject; the properties of the delegate are only
        // known at runtime, hence the untyped result.
        function delegateAt(index): var {
            return instances.objectAt(index);
        }

        // The CommandRunner behind the device query, null while it is not
        // loaded. Its properties are only known at runtime, hence the
        // untyped result.
        function deviceRunner(): var {
            return devicesLoader.item;
        }

        // Asks which interfaces are hardware-backed and which other ones are
        // present. Without a runner there is nobody to ask: every interface
        // counts as physical and none as system virtual.
        function queryDevices() {
            const runner = internals.deviceRunner();
            if (runner !== null) {
                runner.run();
            }
        }

        function applyDeviceList(exitCode, stdout, stderr) {
            if (exitCode !== 0) {
                internals.physical = null;
                internals.virtualNames = null;
                console.warn("netspeeder: device query failed (exit " + exitCode + "): " + stderr);
                return;
            }
            const kinds = Procnetdev.parseDeviceKinds(stdout);
            internals.physical = kinds.physical;
            internals.virtualNames = kinds.virtual;
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
            internals.queryDevices();
        }

        // Brings the delegate model in line with `names` by removing and
        // appending single rows. Interfaces that stay keep their sensors; a
        // wholesale rebuild would show them with zero values for a moment.
        function syncModel(names) {
            const current = [];
            for (let row = 0; row < interfaceModel.count; row++) {
                current.push(interfaceModel.get(row).interfaceName);
            }
            for (const step of ListSync.syncOps(current, names)) {
                if (step.op === "remove") {
                    interfaceModel.remove(step.index);
                } else {
                    interfaceModel.insert(step.index, { "interfaceName": step.name });
                }
            }
        }

        function emitSample() {
            const now = Date.now();
            if (!SensorCode.heartbeatAllows(internals.heartbeatGate, now, root.interval)) {
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
            root.sampleReady(SensorCode.buildSensorSample(now, values, internals.physical, internals.virtualNames));
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

    // Repeats the device query: a VPN tunnel or a container bridge can appear
    // without a change in the interfaces the sensors offer, and the usage
    // totals must still see it as virtual.
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: internals.queryDevices()
    }

    // Tells which interfaces are hardware-backed (kind "physical") and which
    // other ones are present (systemVirtual). It is loaded from its file
    // instead of being declared here: CommandRunner imports plasma5support,
    // and where that module is missing this source must still deliver the
    // readings. internals.physical and internals.virtualNames then stay null:
    // every interface counts as physical and none as system virtual.
    Loader {
        id: devicesLoader

        source: "CommandRunner.qml"

        onLoaded: {
            const runner = internals.deviceRunner();
            runner.command = Procnetdev.DEVICES_COMMAND;
            runner.finished.connect(internals.applyDeviceList);
        }
        onStatusChanged: {
            if (devicesLoader.status === Loader.Error) {
                console.warn("netspeeder: device query unavailable, treating every interface as physical");
            }
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
    }

    // Without a heartbeat sensor (missing in this Plasma version, or
    // ksystemstats not running yet) the check would block all samples, so it
    // is switched off until a heartbeat arrives.
    Timer {
        interval: root.heartbeatProbeMs
        running: true
        onTriggered: internals.updateGate({ type: "probe-expired", sensorReady: root.heartbeatSensorReady })
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.running
        onTriggered: internals.emitSample()
    }
}
