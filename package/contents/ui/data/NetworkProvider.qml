// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The one component all views read. Loads the configured data source
// (ksystemstats or /proc/net/dev), falls back from the first to the second in
// auto mode, feeds the samples into the state machine of providerstate.mjs and
// exposes what it derives: sums, interface list, freshness and error state.

import QtQuick
import "../../code/providerstate.mjs" as ProviderState

Item {
    id: root

    // "auto", "sensors" or "proc"; anything else counts as "auto".
    property string dataSource: "auto"
    // "auto" or "manual"; see selection.mjs.
    property string interfaceSelection: "auto"
    // Interface names summed in manual mode.
    property var selectedInterfaces: []
    // Update interval in seconds, clamped to 0.5 .. 10.
    property real updateInterval: 1.0

    // Test seams. A relative sensorSourceUrl is resolved against this file
    // (the default depends on it); tests pass absolute URLs.
    property url sensorSourceUrl: "SensorSource.qml"
    // How long a loaded sensor source may report no interface before it
    // counts as unavailable.
    property int fallbackDelayMs: 10000

    // Everything below is derived from the state; see derive() in
    // providerstate.mjs.
    readonly property bool hasData: internals.view.hasData
    readonly property real down: internals.view.down
    readonly property real up: internals.view.up
    readonly property bool online: internals.view.online
    readonly property bool stale: internals.view.stale
    // "sensors", "proc", or "" while there is no data.
    readonly property string activeSource: internals.view.activeSource
    // Rows for the popup: the sample fields plus name and included.
    readonly property var interfaces: internals.view.interfaces
    readonly property int includedCount: internals.view.includedCount
    readonly property string primaryLabel: internals.view.primaryLabel
    readonly property string primaryIp: internals.view.primaryIp
    // "", "sensors-unavailable", "no-interfaces" or "source-failed".
    readonly property string errorCode: internals.view.errorCode
    readonly property string errorDetail: internals.view.errorDetail
    // Why auto mode switched to /proc, "" if it did not.
    readonly property string fallbackNote: internals.view.fallbackNote

    onDataSourceChanged: internals.applyChoice()
    onSensorSourceUrlChanged: internals.applyChoice()

    // Choosing the source must wait until all initial property values are in.
    Component.onCompleted: {
        internals.ready = true;
        internals.applyChoice();
    }

    QtObject {
        id: internals

        readonly property url procUrl: "ProcSource.qml"
        readonly property int intervalMs: {
            const seconds = Number(root.updateInterval);
            return Math.round(Math.min(10, Math.max(0.5, isFinite(seconds) ? seconds : 1)) * 1000);
        }

        property var state: ProviderState.initialState()
        property real now: Date.now()
        readonly property var view: ProviderState.derive(internals.state, {
            mode: root.interfaceSelection,
            selected: root.selectedInterfaces,
            now: internals.now,
            intervalMs: internals.intervalMs
        })

        property bool ready: false
        // "auto", "sensors" or "proc" as last applied, and the mode plus the
        // URL of the source behind it. A new key means a new source.
        property string appliedMode: ""
        property string appliedKey: ""
        // True after auto mode gave up on the sensor source.
        property bool fallenBack: false
        // True while the loaded source is the sensor source.
        property bool sensorsActive: false
        // True once the sensor source has offered an interface.
        property bool interfacesSeen: false
        // What the loader loads; empty before the first choice.
        property url loadedUrl
        // The last failure message that was logged, to log each one once.
        property string lastWarning: ""

        // The properties of the loaded item are only known at runtime, hence
        // the untyped result.
        function sourceItem(): var {
            return loader.item;
        }

        function chosenMode() {
            return root.dataSource === "proc" || root.dataSource === "sensors" ? root.dataSource : "auto";
        }

        function dispatch(event) {
            internals.state = ProviderState.reduce(internals.state, event);
        }

        // Loads the source that dataSource and sensorSourceUrl ask for. Does
        // nothing when that is the source already in use, so a change that
        // does not affect the effective source (for example a new
        // sensorSourceUrl while /proc is in use) keeps the displayed values.
        function applyChoice() {
            if (!internals.ready) {
                return;
            }
            const mode = internals.chosenMode();
            if (mode !== internals.appliedMode) {
                // A new choice ends an earlier fallback.
                internals.fallenBack = false;
            }
            const useProc = mode === "proc" || internals.fallenBack;
            const url = useProc ? internals.procUrl : root.sensorSourceUrl;
            const key = mode + "|" + url;
            if (key === internals.appliedKey) {
                return;
            }
            internals.appliedMode = mode;
            internals.appliedKey = key;
            internals.sensorsActive = !useProc;
            internals.interfacesSeen = false;
            internals.lastWarning = "";
            // The old source's data must be gone before the new one can fail
            // or deliver.
            internals.dispatch({ type: "source-changed" });
            internals.loadedUrl = url;
            // The loader keeps its item when the URL did not change (for
            // example auto -> sensors), so look at it again.
            internals.noteAvailability();
            internals.armFallbackTimer();
            // The loader reports an error only when its status changes. A new
            // choice that meets the same failed load (sensors -> auto with an
            // unloadable sensor source) or another failed one gets no report.
            if (loader.status === Loader.Error) {
                Qt.callLater(internals.handleLoadError);
            }
        }

        // Auto mode gives up on the sensor source and continues with /proc.
        // No source-changed here: that would drop the reason for the switch.
        function fallBack(reason) {
            console.warn("netspeeder: using /proc instead of ksystemstats (" + reason + ")");
            internals.dispatch({ type: "fallback", reason: reason });
            internals.fallenBack = true;
            internals.sensorsActive = false;
            internals.interfacesSeen = false;
            internals.appliedKey = internals.appliedMode + "|" + internals.procUrl;
            fallbackTimer.stop();
            internals.loadedUrl = internals.procUrl;
        }

        // The sensor source cannot be used: auto mode falls back, a fixed
        // source stays and reports it.
        function sensorsFailed(reason) {
            if (internals.appliedMode === "auto") {
                internals.fallBack(reason);
            } else {
                internals.dispatch({ type: "unavailable", reason: reason });
            }
        }

        // Runs from the loader's error status, deferred: a source change must
        // not happen while the loader is still delivering the status change
        // of the load that triggered it.
        function handleLoadError() {
            if (loader.status !== Loader.Error) {
                return;
            }
            console.warn("netspeeder: cannot load data source " + internals.loadedUrl);
            if (internals.sensorsActive) {
                internals.sensorsFailed("sensors-unavailable");
            } else {
                internals.dispatch({ type: "failed", message: "cannot load " + internals.loadedUrl });
            }
        }

        function noInterfaces() {
            internals.noteAvailability();
            if (internals.sensorsActive && !internals.interfacesSeen) {
                internals.sensorsFailed("no-interfaces");
            }
        }

        // Remembers that the sensor source has offered an interface; from then
        // on an empty list means "all interfaces gone", not "never found any".
        function noteAvailability() {
            const item = internals.sourceItem();
            if (item !== null && item.available === true) {
                internals.interfacesSeen = true;
                fallbackTimer.stop();
            }
        }

        // Starts the countdown to "no interface found" for a freshly loaded
        // sensor source.
        function armFallbackTimer() {
            fallbackTimer.stop();
            if (internals.sensorsActive && !internals.interfacesSeen && loader.status === Loader.Ready) {
                fallbackTimer.start();
            }
        }

        // A persistently failing source reports on every tick; each distinct
        // message is logged once per failure episode.
        function logFailure(message) {
            if (message !== internals.lastWarning) {
                internals.lastWarning = message;
                console.warn("netspeeder: " + message);
            }
        }
    }

    Loader {
        id: loader

        source: internals.loadedUrl

        onLoaded: {
            internals.noteAvailability();
            internals.armFallbackTimer();
        }
        onStatusChanged: {
            if (loader.status === Loader.Error) {
                Qt.callLater(internals.handleLoadError);
            }
        }
    }

    Binding {
        target: loader.item
        property: "interval"
        value: internals.intervalMs
        when: loader.item !== null
    }

    Connections {
        target: loader.item

        function onSampleReady(sample) {
            internals.lastWarning = "";
            internals.dispatch({ type: "sample", sample: sample, now: Date.now() });
        }

        function onFailed(message) {
            internals.logFailure(message);
            internals.dispatch({ type: "failed", message: message });
        }

        function onAvailableChanged() {
            internals.noteAvailability();
        }
    }

    Timer {
        id: fallbackTimer

        interval: root.fallbackDelayMs
        onTriggered: internals.noInterfaces()
    }

    // Moves "now" forward so that staleness shows up without a new sample.
    Timer {
        interval: internals.intervalMs
        repeat: true
        running: true
        onTriggered: internals.now = Date.now()
    }
}
