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
