module.exports = {
  root: true, // Makes ESLint stop looking in parent folders
  env: {
    node: true,
    browser: true, // Add browser environment for frontend code
  },
  extends: [
    'plugin:vue/vue3-essential', // Base Vue 3 rules
    'eslint:recommended',        // Standard ESLint recommended rules
    '@vue/typescript/recommended', // TypeScript specific rules for Vue (from your devDependencies)
    // Add any other plugins or configs like Prettier if you use them
    // e.g., 'plugin:prettier/recommended'
  ],
  parserOptions: {
    ecmaVersion: 2020, // Allows for modern ECMAScript syntax
    // parser: '@typescript-eslint/parser', // Already handled by @vue/typescript/recommended
  },
  rules: {
    // Your custom rules or overrides
    'no-console': process.env.NODE_ENV === 'production' ? 'warn' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'warn' : 'off',
    // Add other rules as needed
  },
  overrides: [
    {
      files: [
        '**/__tests__/*.{j,t}s?(x)',
        '**/tests/unit/**/*.spec.{j,t}s?(x)'
      ],
      env: {
        jest: true
      }
    }
  ]
};