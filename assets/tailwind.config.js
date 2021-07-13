module.exports = {
  purge: {
    content: [
      "./js/**/*.js",
      "../lib/t_web/templates/**/*.*eex",
      "../lib/t_web/live/**/*ex",
      "../lib/t_web/helpers/**/*ex",
      "../lib/t_web/components/**/*ex",
    ],
    options: {
      safelist: {
        deep: [/nprogress/],
      },
    },
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
