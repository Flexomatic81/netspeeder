<!--
SPDX-License-Identifier: GPL-2.0-or-later
SPDX-FileCopyrightText: 2026 Flexomatic81
-->

# Security policy

## Supported versions

Only the latest release gets fixes. Please check that a problem still happens
with it before reporting.

## Reporting a problem

Please do not open a public issue for a security problem. Report it privately
through [Report a vulnerability](https://github.com/Flexomatic81/netspeeder/security/advisories/new)
under the repository's Security tab; only the maintainer sees the report.

Describe what an attacker could do, how to reproduce it and which version you
used. You will get an answer as soon as possible; a fix goes into a new release,
and the report is published once the fix is out.

Netspeeder runs inside Plasma with the rights of the logged-in user. It reads
network counters, starts `vnstat` when usage is enabled, and starts the
programs and commands that its click actions are set to.
