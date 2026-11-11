module.exports = {
  // Vue CLI 4 / Webpack 4 must transpile modern syntax used by Supabase's
  // distributed dependencies (optional chaining and nullish coalescing).
  transpileDependencies: [
    "vuetify",
    "@supabase",
    "iceberg-js"
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
