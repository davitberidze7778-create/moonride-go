module.exports = {
  // Vue CLI 5 / Webpack 5 transpiles modern syntax used by Supabase and
  // TomTom's ESM map dependencies.
  transpileDependencies: [
    "vuetify",
    "@supabase",
    "iceberg-js",
    "@tomtom-org/maps-sdk",
    "maplibre-gl",
    "@turf",
    "culori",
    "lodash-es",
    "zod"
  ],
  configureWebpack: {
    module: {
      rules: [
        {
          test: /\.mjs$/,
          include: /node_modules/,
          type: "javascript/auto"
        }
      ]
    }
  }
}
