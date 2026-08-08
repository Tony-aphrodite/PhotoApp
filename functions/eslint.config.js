/**
 * Flat ESLint config (required from ESLint v9 — `.eslintrc.*` is no longer
 * read, which is why `npm run lint` failed with "couldn't find
 * eslint.config.js" until this file existed).
 */

const tsPlugin = require('@typescript-eslint/eslint-plugin');
const tsParser = require('@typescript-eslint/parser');

module.exports = [
  {
    // Compiled output and dependencies are never linted.
    ignores: ['lib/**', 'node_modules/**'],
  },
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parser: tsParser,
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        // Node globals used across the functions.
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        setTimeout: 'readonly',
        clearTimeout: 'readonly',
        URL: 'readonly',
        TextEncoder: 'readonly',
        TextDecoder: 'readonly',
      },
    },
    plugins: {
      '@typescript-eslint': tsPlugin,
    },
    rules: {
      ...tsPlugin.configs.recommended.rules,

      // The FacturAPI SDK's typings have drifted across 4.x releases, so its
      // clients are deliberately typed `any` (see lib/facturapi.ts). Stripe
      // webhook payloads are likewise narrowed by hand.
      '@typescript-eslint/no-explicit-any': 'off',

      // Firestore documents are untyped maps; unused destructured fields are
      // common and harmless.
      '@typescript-eslint/no-unused-vars': [
        'warn',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],

      'no-console': 'warn',
      eqeqeq: ['error', 'smart'],
      'prefer-const': 'error',
    },
  },
];
