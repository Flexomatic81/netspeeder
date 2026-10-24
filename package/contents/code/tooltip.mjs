// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Which lines the tooltip shows. The texts come from the translation helpers
// passed in (named tr/trc as in the QML files so the catalog extraction finds
// them); this module itself knows no i18n function.

// Escapes what StyledText would read as markup. Only the sub text of the
// tooltip is styled; the main text is plain text and must stay unescaped.
export function escapeHtml(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// The first line that applies describes the state; with live data the speeds
// follow, and the IP address if there is one.
function statusLines(state, t, speedText) {
  if (!state.hasData) {
    return [t.tr("Waiting for network data…")];
  }
  if (state.stale) {
    return [t.tr("No current data")];
  }
  if (state.includedCount === 0 && state.interfaceSelection === "manual") {
    return [t.tr("No selected network interface available")];
  }
  if (state.includedCount === 0 || !state.online) {
    return [t.tr("Offline")];
  }
  const lines = [
    t.trc("@info:tooltip", "Download: %1", speedText(state.down)),
    t.trc("@info:tooltip", "Upload: %1", speedText(state.up)),
  ];
  if (state.primaryIp !== "") {
    lines.push(t.trc("@info:tooltip", "IP address: %1", escapeHtml(state.primaryIp)));
  }
  return lines;
}

// A note about the data source, independent of the status above; empty when
// the source works as chosen.
function hintLines(state, t) {
  const fellBack = state.fallbackNote !== "";
  switch (state.errorCode) {
    case "sensors-unavailable":
      return [
        fellBack
          ? t.tr("Using kernel counters because system sensors are not available.")
          : t.tr("System sensors are not available. Choose another data source in the settings."),
      ];
    case "no-interfaces":
      return [
        fellBack
          ? t.tr("Using kernel counters because system sensors report no network interfaces.")
          : t.tr("System sensors report no network interfaces."),
      ];
    case "source-failed":
      // Cut first, escape second: a cut must not split an entity.
      return [
        t.tr("Reading network data failed: %1", escapeHtml(state.errorDetail.replace(/[\r\n]+/g, " ").slice(0, 120))),
      ];
    default:
      return [];
  }
}

// state: { hasData, stale, includedCount, interfaceSelection, online, down,
// up, primaryIp, errorCode, errorDetail, fallbackNote }; t: { tr, trc };
// speedText: bytes per second -> "1.5 KiB/s".
export function tooltipLines(state, t, speedText) {
  return statusLines(state, t, speedText).concat(hintLines(state, t));
}
