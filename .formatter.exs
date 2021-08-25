[
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test,dev,bench}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
