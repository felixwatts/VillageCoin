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
      { from: './app/proposeAppointGatekeeper.html', to: "proposeAppointGatekeeper.html" },
      { from: './app/proposals.html', to: "proposals.html" },
      { from: './app/proposal.html', to: "proposal.html" },
      { from: './app/welcome.html', to: "welcome.html" },
      { from: './app/createProposal.html', to: "createProposal.html" },
      { from: './app/requestCitizenship.html', to: "requestCitizenship.html" },
      { from: './app/villageIndex.html', to: "villageIndex.html" },
      { from: './app/createVillage.html', to: "createVillage.html" },
      { from: './app/villages.html', to: "villages.html" }
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
