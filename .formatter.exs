[
  import_deps: [:ecto, :phoenix],
  inputs: [
    "*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "{config,lib,test,dev,bench}/**/*.{heex,ex,exs}"
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter]
]
