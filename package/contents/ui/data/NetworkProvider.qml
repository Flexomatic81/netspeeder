// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The one component all views read. Loads the configured data source
// (ksystemstats or /proc/net/dev), falls back from the first to the second in
// auto mode, feeds the samples into the state machine of providerstate.mjs and
// exposes what it derives: sums, interface list, freshness and error state.

import QtQuick
import "../../code/providerstate.mjs" as ProviderState
import "../../code/history.mjs" as History
import "../../code/visibility.mjs" as Visibility

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
    // Idle means: down plus up stayed below idleThreshold (bytes per second)
    // for idleSeconds.
    property int idleThreshold: 1024
    property int idleSeconds: 30

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
    readonly property bool stale: internals.stale
    readonly property bool idle: internals.idleState.idle
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
    // Rolling traffic history of the included interfaces: down, up and times
    // lists, peakDown/peakUp, and the session totals sessionDown/sessionUp.
    // A new object after every sample; see history.mjs.
    readonly property var history: internals.history

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

        onIntervalMsChanged: internals.history = History.resize(internals.history, History.capacityFor(internals.intervalMs))

        property var state: ProviderState.initialState()
        property var history: History.createHistory(History.capacityFor(internals.intervalMs))
        property real now: Date.now()
        // Everything the views show except `stale`. This binding must not
        // read the clock: derive() builds new objects on every call, so a
        // re-derive on each clock tick would hand views (a popup list, say) a
        // new `interfaces` array between two samples and have them rebuild
        // it. With `now` fixed at the time of the last sample, view.stale is
        // always false; it is not used.
        readonly property var view: ProviderState.derive(internals.state, {
            mode: root.interfaceSelection,
            selected: root.selectedInterfaces,
            now: internals.state.lastSampleAt,
            intervalMs: 1
        })
        // The only output that follows the clock. derive() stays the one
        // place that knows the staleness rule; the selection does not matter
        // for it and is left out.
        readonly property bool stale: ProviderState.derive(internals.state, {
            mode: "auto",
            selected: [],
            now: internals.now,
            intervalMs: internals.intervalMs
        }).stale

        // Result of Visibility.nextIdle(); `idle` is its output.
        property var idleState: ({ belowSince: null, lastNow: null, idle: false })

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

        // Evaluates idleness at `now`, on every sample and every clock tick.
        // Without data the traffic is unknown, which counts as activity.
        function evaluateIdle(now) {
            const v = internals.view;
            internals.idleState = Visibility.nextIdle(internals.idleState, {
                total: v.hasData ? v.down + v.up : NaN,
                now: now,
                threshold: root.idleThreshold,
                seconds: root.idleSeconds
            });
        }

        // Counter baselines of one source mean nothing for the next, and
        // neither does the quiet period measured on the old one.
        function forgetBaselines() {
            internals.history = History.resetBaselines(internals.history);
            internals.idleState = { belowSince: null, lastNow: null, idle: false };
        }

        // Adds the sample just dispatched to the history. Totals come from the
        // included interfaces only; an ignored empty sample adds nothing.
        function recordHistory(now) {
            if (!internals.view.hasData) {
                return;
            }
            const totals = {};
            const rows = internals.view.interfaces;
            for (let i = 0; i < rows.length; i++) {
                if (rows[i].included) {
                    totals[rows[i].name] = {
                        down: rows[i].totalDown,
                        up: rows[i].totalUp,
                        known: rows[i].totalsKnown === true
                    };
                }
            }
            internals.history = History.pushSample(internals.history, {
                timestamp: now,
                down: internals.view.down,
                up: internals.view.up,
                totals: totals
            });
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
            internals.forgetBaselines();
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
            internals.forgetBaselines();
            internals.fallenBack = true;
            internals.sensorsActive = false;
            internals.interfacesSeen = false;
            internals.appliedKey = internals.appliedMode + "|" + internals.procUrl;
            fallbackTimer.stop();
            internals.loadedUrl = internals.procUrl;
            // A sensor source that failed to load leaves the loader in the
            // error state, and /proc failing to load too is no status change,
            // so it would go unreported.
            if (loader.status === Loader.Error) {
                Qt.callLater(internals.handleLoadError);
            }
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
            const now = Date.now();
            internals.dispatch({ type: "sample", sample: sample, now: now });
            internals.recordHistory(now);
            internals.evaluateIdle(now);
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
        onTriggered: {
            internals.now = Date.now();
            internals.evaluateIdle(internals.now);
        }
    }
}
