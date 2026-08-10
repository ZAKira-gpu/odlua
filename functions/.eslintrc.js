module.exports = {
  env: {
    es2022: true, // Enables modern JS (optional chaining, etc.)
    node: true, // Enables Node globals like require, module, process
  },
  parserOptions: {
    ecmaVersion: 2022, // Full modern syntax support
    sourceType: "script", // For CommonJS modules (require/exports)
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    // --- Code style & safety ---
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", { "allowTemplateLiterals": true }],
    "semi": ["error", "always"],
    "object-curly-spacing": ["error", "always"],
    "no-unused-vars": ["warn"],
    "max-len": "off",
    "require-jsdoc": "off",

    // --- Firebase specific ---
    "no-console": "off", // Allow console logs for Cloud Functions
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
