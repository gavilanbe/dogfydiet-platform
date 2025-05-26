// applications/frontend/tailwind.config.js
/** @type {import('tailwindcss').Config} */
const colors = require('tailwindcss/colors');

module.exports = {
  content: [
    "./public/index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        'inter': ['Inter', 'system-ui', 'sans-serif'],
      },
      colors: {
        'brand-pink': '#ec4899',
        'brand-purple': '#8b5cf6',
        pink: colors.pink,
        purple: colors.purple,
        gray: colors.coolGray,
        // For the gradient in .gradient-bg from style.css
        indigo: colors.indigo, // Added this as it's used in .gradient-bg
      }
    },
  },
  plugins: [],
}