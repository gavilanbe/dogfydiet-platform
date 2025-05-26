// applications/frontend/tailwind.config.js
/** @type {import('tailwindcss').Config} */
const colors = require('tailwindcss/colors'); // Add this line

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
        // Add the gray color palette
        gray: colors.coolGray, // You can choose other grays like 'blueGray', 'trueGray', 'warmGray', 'gray' itself
                              // For example, to use the default Tailwind gray:
                              // gray: colors.gray,
      }
    },
  },
  plugins: [],
}