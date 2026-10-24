// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Starts the configured application (desktop id) or shell command. A
// successful start reports nothing; failures are reported through failed().

import QtQuick
import "../../code/command.mjs" as Command

Item {
    id: root

    // "app" (desktop id in app) or "command" (shell text in command).
    property string kind: "app"
    property string app: ""
    property string command: ""
    // Builds the shell line from { kind, app, command }; null = invalid.
    // Replaceable so tests never start a real program.
    property var commandLineFor: Command.launchCommandLine
    // Longest wait for the launch line in milliseconds.
    property int timeoutMs: 5000
    readonly property bool busy: runner.busy

    // code: "invalid", "not-found", "timeout" or "failed"; target: the desktop
    // id or the command that was meant to start.
    signal failed(string code, string target)

    // Starts the target. Ignored while a launch is still running.
    function launch() {
        if (runner.busy) {
            return;
        }
        const target = root.kind === "app" ? root.app : root.command;
        const line = root.commandLineFor({ kind: root.kind, app: root.app, command: root.command });
        if (line === null) {
            root.failed("invalid", target);
            return;
        }
        internals.target = target;
        runner.command = line;
        runner.run();
    }

    QtObject {
        id: internals

        property string target: ""
    }

    CommandRunner {
        id: runner

        timeoutMs: root.timeoutMs
        onFinished: (exitCode, stdout, stderr) => {
            const code = Command.launchFailure(exitCode);
            if (code !== null) {
                root.failed(code, internals.target);
            }
        }
    }
}
