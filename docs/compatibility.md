<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Compatibility

## Supported versions

Netspeeder needs **Plasma 6.3 or newer**, with
**KDE Frameworks 6.10 or newer** and **Qt 6.8 or newer**. This is the oldest
combination the code was checked against: every QML module, type, property and language feature the
applet uses is listed below with the release-tagged source that shows it in
that version. Nothing the applet uses was missing there, so no fallback code
and no higher minimum were needed.

### What has been tested, and what has only been checked

Netspeeder has run on **Plasma 6.8 with KDE Frameworks 6.31 and Qt 6.12**
only. The minimum of Plasma 6.3, Frameworks 6.10 and Qt 6.8 rests on the
source audit below alone: it reads source files at release tags and does not
replace a run on a real desktop. No release so far has been run on Plasma 6.3
to 6.7.

If you use one of these versions, the
[checklist at the end](#checklist-for-an-older-plasma-version) lists what only
a real run can show. Reports of what works and what does not are welcome as
an issue.

### `X-Plasma-API-Minimum-Version` stays at `6.0`

`package/metadata.json` sets `"X-Plasma-API-Minimum-Version": "6.0"`. That key
names the generation of the applet API, not a Plasma release, and it is not a
gate for the minimum above:

- libplasma reads it only after an applet has **failed** to load, to word the
  error message: a missing value or a major version other than 6 gives
  "not compatible", a minor version above the running one gives "update
  Plasma" ([`src/plasmaquick/appletquickitem.cpp`@v6.3.0](https://github.com/KDE/libplasma/blob/v6.3.0/src/plasmaquick/appletquickitem.cpp),
  `AppletQuickItemPrivate::createAppletItem` error path).
- The widget explorer hides widgets whose major version is not 6 or whose
  minor version is above a hard-coded 6
  ([`components/shellprivate/plasmaappletitemmodel.cpp`@v6.3.0](https://github.com/KDE/plasma-workspace/blob/v6.3.0/components/shellprivate/plasmaappletitemmodel.cpp),
  `PlasmaAppletItem::isSupported`).

A higher value would therefore not stop installation or loading on an older
Plasma; `6.0` is the value the Plasma 6 templates use
([`templates/qml-plasmoid6/metadata.json`@v6.3.0](https://github.com/KDE/libplasma/blob/v6.3.0/templates/qml-plasmoid6/metadata.json)).
The minimum is stated here and in the README instead.

## Inventory

Sources are files at release tags of the GitHub mirrors of KDE and Qt
(`<repo>` `<path>@<tag>`). Tags used: Plasma `v6.3.0` (libplasma,
plasma-workspace, plasma-desktop, libksysguard, ksystemstats, plasma5support),
Frameworks `v6.10.0` (kirigami, kquickcharts, kdeclarative, knotifications,
kcmutils, frameworkintegration), Qt `v6.8.0` (qtdeclarative).

### QML modules

| Module | Used for | Source |
| --- | --- | --- |
| `QtQuick`, `QtQuick.Layouts`, `QtQuick.Controls`, `QtQml` | Items, layouts, controls, `Instantiator`, `TextMetrics`, `HoverHandler` | Qt 6.0 modules; all types used exist since Qt 5.x ([Qt 6.8 QML types](https://doc.qt.io/qt-6.8/qtquick-qmlmodule.html)) |
| `QtCore` | `StandardPaths.standardLocations(GenericDataLocation)` (Behavior page) | qtdeclarative `src/core/qqmlstandardpaths.cpp@v6.8.0`: `\since 6.2` |
| `QtQuick.Dialogs` | `FileDialog` with `currentFolder`, `selectedFile`, `nameFilters` (Behavior page) | qtdeclarative `src/quickdialogs/quickdialogs/qquickfiledialog.cpp@v6.8.0`: `\since 6.2`, all three properties documented |
| `org.kde.kirigami` | `FormLayout`, `FormData.label`/`isSection`, `InlineMessage` (`type: MessageType.Warning`), `Heading` (`level`), `Icon` (`source`, `color`), `Theme` (`textColor`, `highlightColor`, `linkColor`, `positiveTextColor`, `neutralTextColor`, `negativeTextColor`, `defaultFont`, `smallFont`), `Units` (`gridUnit`, `smallSpacing`, `largeSpacing`, `toolTipDelay`, `cornerRadius`) | kirigami `src/layouts/formlayoutattached.h`, `src/controls/templates/InlineMessage.qml`, `src/controls/Heading.qml`, `src/enums.h`, `src/primitives/icon.h`, `src/platform/platformtheme.h`, `src/platform/units.h`@v6.10.0; `cornerRadius` is marked `@since 6.2`, the newest of these |
| `org.kde.kcmutils` | `SimpleKCM` as the root of every settings page | kcmutils `src/qml/CMakeLists.txt@v6.10.0` (URI `org.kde.kcmutils`, `components/SimpleKCM.qml`) |
| `org.kde.plasma.plasmoid` | `PlasmoidItem` with `compactRepresentation`, `fullRepresentation`, `preferredRepresentation`, `expanded`, `toolTipMainText`, `toolTipSubText`, `toolTipTextFormat`; `Plasmoid.configuration`, `formFactor`, `status`, `containment` | libplasma `src/plasmaquick/appletquickitem.h`, `src/plasmaquick/plasmoid/plasmoiditem.h`, `src/plasma/applet.h`@v6.3.0 |
| `org.kde.plasma.core` | `Types.Planar`, `Types.Vertical`, `Types.ActiveStatus`, `Types.HiddenStatus` | libplasma `src/plasma/plasma.h@v6.3.0` |
| `org.kde.plasma.configuration` | `ConfigModel`, `ConfigCategory` (`name`, `icon`, `source`) in `config/config.qml` | libplasma `src/plasmaquick/configmodel.h`, `src/plasmaquick/configcategory_p.h`@v6.3.0 |
| `org.kde.plasma.plasma5support` | `DataSource` with `engine: "executable"`, `connectSource`, `disconnectSource`, `newData` (only in `CommandRunner.qml`) | plasma5support `src/declarativeimports/datasource.h`, `src/declarativeimports/CMakeLists.txt`@v6.3.0 |
| `org.kde.ksysguard.sensors` | `Sensor` (`sensorId`, `value`, `status`, `Sensor.Ready`, `updateRateLimit`), `SensorTreeModel` (role `SensorTreeModel.SensorId`) | libksysguard `sensors/Sensor.h`, `sensors/SensorTreeModel.h`, `sensors/CMakeLists.txt`@v6.3.0 |
| `org.kde.quickcharts` | `LineChart` (`lineWidth`, `fillOpacity`, `colorSource`, `valueSources`, `xRange`/`yRange` with `from`, `to`, `automatic`), `ArraySource` (`array`) | kquickcharts `src/LineChart.h`, `src/XYChart.h`, `src/RangeGroup.h`, `src/Chart.h`, `src/datasource/ArraySource.h`@v6.10.0 |
| `org.kde.quickcharts.controls` | `AxisLabels` (`direction: VerticalBottomTop`, `constrainToBounds`, `delegate`, `source`, attached `label`), `GridLines` (`chart`, `direction: Vertical`, `major`/`minor` with `count`, `lineWidth`, `color`) | kquickcharts `controls/AxisLabels.h`, `controls/GridLines.h`, `controls/CMakeLists.txt`@v6.10.0 |
| `org.kde.kquickcontrols` | `ColorButton` (`color`, `dialogTitle`, `showAlphaChannel`, signal `accepted(color)`) | kdeclarative `src/qmlcontrols/kquickcontrols/ColorButton.qml@v6.10.0` |
| `org.kde.kquickcontrolsaddons` | `Clipboard.content` (copy buttons in the popup) | kdeclarative `src/qmlcontrols/kquickcontrolsaddons/clipboard.h@v6.10.0` |
| `org.kde.notification` | `Notification` (`componentName`, `eventId`, `title`, `text`, `iconName`, `sendEvent()`) | knotifications `src/qml/knotificationqmlplugin.h`, `src/qml/CMakeLists.txt`, `src/knotification.h`@v6.10.0 (`sendEvent` is a public slot) |

### Contracts that are not documented API

| Contract | Used for | Source |
| --- | --- | --- |
| Sensor IDs `network/<interface>/download`, `upload`, `totalDownload`, `totalUpload`, `network`, `ipv4address`, `ipv6address`, `signal` | Default data source | ksystemstats `plugins/network/NetworkPlugin.cpp@v6.3.0` (container `network`), `plugins/network/NetworkDevice.cpp@v6.3.0` (all eight property IDs), `plugins/network/RtNetlinkBackend.cpp` and `NetworkManagerBackend.cpp`@v6.3.0 (object ID = interface name) |
| Sensor ID `os/system/uptime` | Heartbeat that tells a quiet network from stalled sensors | ksystemstats `plugins/osinfo/osinfo.cpp@v6.3.0` (container `os`, object `system`, property `uptime`, set in every `update()`) |
| `Plasmoid.containment.corona.editMode` | Auto-hide placeholder while the panel is edited | libplasma `src/plasma/applet.h` (`containment`), `src/plasma/containment.h` (`corona`, constant), `src/plasma/corona.h` (`editMode`)@v6.3.0; the panel itself binds to the same chain in plasma-desktop `containments/panel/contents/ui/main.qml@v6.3.0` |
| `HiddenStatus` hides the applet in a panel | Auto-hide | plasma-desktop `containments/panel/contents/ui/main.qml@v6.3.0` and `LayoutManager.js`: an applet with `HiddenStatus` is invisible unless the panel is being configured |
| Executable engine data keys `exit code`, `stdout`, `stderr` | `CommandRunner.qml` | The engine ships with plasma-workspace, not plasma5support: `dataengines/executable/executable.cpp@v6.3.0` |
| Notification event `plasma_workspace` / `notification` | Launch failures, data cap | frameworkintegration `plasma_workspace.notifyrc@v6.10.0` (`[Event/notification]`) |

### QML and JavaScript language features

| Feature | Where | Available since | Source |
| --- | --- | --- | --- |
| `pragma ComponentBehavior: Bound` | 7 files | Qt 6.4 | qtdeclarative `src/qml/compiler/qqmlirbuilder.cpp`: absent at v6.3.0, handled at v6.4.0; documented in `src/qml/doc/src/qmllanguageref/documents/structure.qdoc@v6.8.0` |
| Typed function parameters and return types | all views | Qt 5.15; enforced at call time since Qt 6.7 | `src/qml/doc/src/javascript/hostenvironment.qdoc@v6.8.0`, "Type annotations and assertions" |
| `as` type assertion (`graphLoader.item as Item`) | `FullRepresentation.qml` | Qt 5.15 | parser rule `TypeAssertExpression` in qtdeclarative `src/qml/parser/qqmljs.g@v5.15.0` (`QSOperator::As`, also at v6.0.0); documented in `hostenvironment.qdoc` from v6.2.0 (not yet at v6.0.0), still at v6.8.0 |
| `??` and `?.` (also `?.[...]` in `clicks.mjs`) | views and modules | `??` Qt 5.15, `?.` Qt 6.2 | `hostenvironment.qdoc@v6.8.0` |
| Arrow functions, rest and spread arguments, template literals, `.mjs` modules imported into QML | everywhere | Qt 5.12 (ECMAScript 7th edition) | `hostenvironment.qdoc@v6.8.0` ("implements the 7th edition") |
| `String.prototype.padStart` | `appearance.mjs` | present in Qt 6.8 | qtdeclarative `src/qml/jsruntime/qv4stringobject.cpp@v6.8.0` |
| `Qt.alpha` | `TrafficGraph.qml`, `FullRepresentation.qml` | Qt 6.0 | qtdeclarative `src/qml/qml/v8/qqmlbuiltinfunctions.cpp@v6.0.0` (`QtObject::alpha`; absent at v5.15.0), moved to `src/qml/qml/qqmlbuiltinfunctions.cpp` by v6.3.0, still there at v6.8.0 |
| `Qt.resolvedUrl`, `Qt.binding`, `Qt.callLater`, `Qt.fontFamilies`, `Qt.locale`, `Qt.openUrlExternally` | views | Qt 5.x | `qqmlbuiltinfunctions.cpp@v6.8.0` |
| `required property`, `Connections` with `function onX()` handlers | delegates, views | Qt 5.15 | [Qt 6.8 QML object attributes](https://doc.qt.io/qt-6.8/qtqml-syntax-objectattributes.html) |
| `Item.grabToImage` | `tools/screenshots` only, not shipped | Qt 5.4 | [Qt 6.8 Item](https://doc.qt.io/qt-6.8/qml-qtquick-item.html) |

The project's own checks run on a newer Qt. Two limits of the QML engine that
matter for older versions are already avoided by the code: `catch` always has
a binding, and `String.prototype.trimStart` is not used.

## Checklist for an older Plasma version

Not part of the release checks: no release has been run through this list.
It covers what the source audit cannot show. Debian 13, for example, ships
Plasma 6.3 and Qt 6.8 with a Frameworks release newer than 6.10. Use a test
user; note the result of every line.

**Setup**

- [ ] Record the versions: `plasmashell --version`, `kpackagetool6 --version`
      (Frameworks) and `qtpaths6 --qt-version`. They must be at least Plasma
      6.3, Frameworks 6.10 and Qt 6.8. `qtpaths6` is one of Qt's development
      tools and is often missing on a plain desktop; the package versions
      show the same: `dpkg-query -W plasma-workspace 'libkf6coreaddons6*' 'libqt6core6*'`.
- [ ] Build the package on the development machine with
      `scripts/build-plasmoid.sh <version>`, copy `dist/netspeeder-<version>.plasmoid`
      to the VM and install it with
      `kpackagetool6 --type Plasma/Applet --install netspeeder-<version>.plasmoid`.
      Log out and in again.
- [ ] Add "Netspeeder" from the widget explorer to a panel. The explorer lists
      it (API key `6.0` accepted) and the applet loads without an error box.
- [ ] `journalctl --user -b | grep -i netspeeder` shows no QML warning about a
      missing module, type or property.

**Panel and popup**

- [ ] Horizontal panel at the bottom: both speeds show, the width does not jump
      while the values change.
- [ ] Vertical panel at the left: the stacked layout shows, nothing is cut off.
- [ ] Desktop: the widget shows the full view.
- [ ] Left click opens the popup: speeds, interface list, traffic graph with
      axis labels and grid lines, usage panel. Copy an address with the copy
      button and paste it elsewhere (clipboard).
- [ ] The tooltip shows one line per entry (`toolTipTextFormat` styled text),
      not a literal `<br>`.
- [ ] The "System Monitor" button in the popup starts the system monitor.

**Settings pages**

- [ ] Open each page: Display, Appearance, Data, Usage, Behavior. Each opens
      without an error and with the form layout aligned.
- [ ] Appearance: the color buttons open a color dialog without an alpha
      channel; a threshold row can be added, changed and removed.
- [ ] Behavior: with neither click set to the popup, the warning message
      appears. "Choose…" for the application opens a file dialog in
      `/usr/share/applications`; picking a `.desktop` file stores its ID.
- [ ] Data: the interface list fills, the source row names the active source.

**Data sources**

- [ ] Default (sensors): Data page shows "System sensors"; the speeds follow a
      download. This confirms the sensor IDs `network/<interface>/…`.
- [ ] Stop the sensor service while the widget runs
      (`systemctl --user stop plasma-ksystemstats`): after a few seconds the
      popup marks the data as stale instead of showing frozen speeds
      (heartbeat `os/system/uptime`). Start it again: the speeds come back.
- [ ] Kernel-counter fallback: `systemctl --user mask --now plasma-ksystemstats`,
      log out and in. About ten seconds after login the automatic mode
      switches to the kernel counters, the tooltip and the Data page say so,
      and the speeds update. This confirms the executable engine of
      plasma-workspace on Debian. Undo with
      `systemctl --user unmask plasma-ksystemstats` and log out and in.
- [ ] Fix the source to "Kernel counters": a VPN or `tun0` interface (if one
      exists) appears in the list.
- [ ] Interfaces in the list are marked physical or virtual correctly
      (device query through the executable engine).

**Auto-hide and edit mode**

- [ ] Set auto-hide to "When offline" and disconnect the network: the applet
      disappears from the panel and leaves no gap (`HiddenStatus`).
- [ ] Enter edit mode while it is hidden: a placeholder icon appears and can be
      moved or configured (`Plasmoid.containment.corona.editMode`). Leave edit
      mode: it disappears again. Reconnect: it comes back.
- [ ] Same with "When idle" and a low threshold.

**Usage (vnstat)**

- [ ] Without `vnstat` installed: the Usage page and the popup say that vnstat
      is missing; nothing else breaks.
- [ ] `apt install vnstat`, enable the service, wait for the first data: the
      usage panel shows today, the billing period and the per-day table.
- [ ] Set a data cap below the current usage: one notification "data cap
      reached" appears (event `plasma_workspace/notification`) and the panel
      dot turns red. Changing the setting again does not repeat it.

**Notifications**

- [ ] Set the left click to launch a command that does not exist and click: a
      notification names the failure.

**German**

- [ ] Switch the system language to German (`Deutsch`), log out and in: the
      panel tooltip, popup, all settings pages and the notifications are in
      German, numbers use a decimal comma.
