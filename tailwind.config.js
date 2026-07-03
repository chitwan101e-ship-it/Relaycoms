/** @type {import('tailwindcss').Config} */
module.exports = {
  // Scan all of src so route groups like app/(auth)/... are always included (fixes missing Tailwind output).
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#f0fdfa',
          100: '#ccfbf1',
          300: '#5eead4',
          500: '#0d9488',
          600: '#0f766e',
        },
      },
      fontFamily: {
        display: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
