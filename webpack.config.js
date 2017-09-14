const path = require('path');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = {
  entry: './app/javascripts/common.js',
  output: {
    path: path.resolve(__dirname, 'build'),
    filename: 'common.js'
  },
  plugins: [
    // Copy our app's index.html to the build folder.
    new CopyWebpackPlugin([
      { from: './app/index.html', to: "index.html" },
      { from: './app/createManager.html', to: "createManager.html" },
      { from: './app/createAccount.html', to: "createAccount.html" },
      { from: './app/proposals.html', to: "proposals.html" },
      { from: './app/welcome.html', to: "welcome.html" },
      { from: './app/gatekeeper.html', to: "gatekeeper.html" },
      { from: './app/createProposal.html', to: "createProposal.html" }
    ])
  ],
  module: {
    rules: [
      {
       test: /\.css$/,
       use: [ 'style-loader', 'css-loader' ]
      }
    ],
    loaders: [
      { test: /\.json$/, use: 'json-loader' },
      {
        test: /\.js$/,
        exclude: /(node_modules|bower_components)/,
        loader: 'babel-loader',
        query: {
          presets: ['es2015'],
          plugins: ['transform-runtime']
        }
      }
    ]
  }
}
