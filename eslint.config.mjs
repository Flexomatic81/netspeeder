// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import js from "@eslint/js";
import globals from "globals";

export default [
    {
        ignores: ["node_modules/", "dist/", "build/", "package/contents/locale/"],
    },
    {
        files: ["**/*.mjs"],
        ...js.configs.recommended,
        languageOptions: {
            ecmaVersion: 2022,
            sourceType: "module",
        },
        rules: {
            ...js.configs.recommended.rules,
            complexity: ["error", 10],
            "max-depth": ["error", 4],
            "max-params": ["error", 5],
            eqeqeq: ["error", "always"],
            "no-var": "error",
            "prefer-const": "error",
            "no-shadow": "error",
            "no-implicit-coercion": "error",
            "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
        },
    },
    {
        files: ["tests/**/*.mjs", "tools/**/*.mjs"],
        languageOptions: {
            globals: globals.node,
        },
    },
];
