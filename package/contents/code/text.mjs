// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Text helpers shared by the QML files. The translation itself is done by
// Plasma's i18n functions in each file (see the tr/trc/trp helpers there);
// this module only supplies the English fallback used where Plasma is absent.

// Replaces %1 … %9 with the arguments; a placeholder without a matching
// argument stays as it is.
export function substitute(text, args) {
  return text.replace(/%([1-9])/g, (placeholder, digit) => {
    const index = Number(digit) - 1;
    return index < args.length ? String(args[index]) : placeholder;
  });
}

// The English text for a count: the singular for exactly 1, otherwise the
// plural. %1 is the count itself, the further arguments follow as %2, %3, …
export function pluralFallback(singular, plural, n, args) {
  return substitute(n === 1 ? singular : plural, [n, ...args]);
}

// "192.168.1.121 · Online": the address and the (already translated) status
// of the header, joined by one separator. A missing part leaves no separator.
export function headerDetails(ip, status) {
  return [ip, status].filter((part) => typeof part === "string" && part !== "").join(" · ");
}

// What one character of a spin box text contributes to the number: itself for
// a digit, "." for the decimal point (only with decimals), "" for a group
// separator (a space-like one also matches any white space), null when the
// number has ended.
function numberPart(char, locale, decimals) {
  const spaceGroup = /^\s*$/.test(locale.groupSeparator);
  if (char >= "0" && char <= "9") {
    return char;
  }
  if (char === locale.groupSeparator || (spaceGroup && /\s/.test(char))) {
    return "";
  }
  return decimals > 0 && char === locale.decimalPoint ? "." : null;
}

// The number a spin box shows is followed by a unit ("1.024 KiB/s"), so the
// default reading of its text fails. This takes the leading number and drops
// the group separator and the unit. Text without a leading number, such as
// "", "KiB/s", "-5" or garbage, gives the fallback.
export function parseSpinText(text, locale, decimals, fallback) {
  let number = "";
  for (const char of String(text).replace(/^\s+/, "")) {
    const part = numberPart(char, locale, decimals);
    if (part === null) {
      break;
    }
    number += part;
  }
  const value = /^\d/.test(number) ? Number(number) : NaN;
  return Number.isFinite(value) ? value : fallback;
}
