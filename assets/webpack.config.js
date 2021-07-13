const path = require("path");
const CssMinimizerPlugin = require("css-minimizer-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CompressionPlugin = require("compression-webpack-plugin");

module.exports = (env, options) => {
  const devMode = options.mode !== "production";

  return {
    resolve: {
      modules: ["node_modules"],
    },
    optimization: {
      minimizer: ["...", new CssMinimizerPlugin()],
    },
    entry: {
      app: ["./js/app.js"],
    },
    output: {
      filename: "[name].js",
      chunkFilename: "[id].[contenthash].js",
      path: path.resolve(__dirname, "../priv/static/js/"),
      publicPath: "/js/",
    },
    devtool: devMode ? "source-map" : undefined,
    module: {
      rules: [
        {
          test: /\.css$/,
          use: [MiniCssExtractPlugin.loader, "css-loader", "postcss-loader"],
        },
      ],
    },
    plugins: [
      new MiniCssExtractPlugin({ filename: "../css/[name].css" }),
      new CopyWebpackPlugin({ patterns: [{ from: "static/", to: "../" }] }),

      options.mode === "production" &&
        new CompressionPlugin({
          test: /\.(js|css|svg|ttf)$/,
        }),

      options.mode === "production" &&
        new CompressionPlugin({
          filename: "[path][base].br[query]",
          algorithm: "brotliCompress",
          test: /\.(js|css|svg|ttf)$/,
          compressionOptions: {
            level: 11,
          },
          threshold: 10240,
          minRatio: 0.8,
          deleteOriginalAssets: false,
        }),
    ].filter(Boolean),
  };
};
