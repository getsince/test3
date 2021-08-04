module.exports = {
  mode: "jit",
  purge: {
    content: ["./js/**/*.js", "../lib/*_web/**/*.*ex"],
  },
  darkMode: "media",
  theme: {
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [require("@tailwindcss/forms")],
};
