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
      { from: './app/citizens.html', to: "citizens.html" },
      { from: './app/proposals.html', to: "proposals.html" },
      { from: './app/proposal.html', to: "proposal.html" },
      { from: './app/welcome.html', to: "welcome.html" },
      { from: './app/createProposal.html', to: "createProposal.html" },
      { from: './app/proposeSetParameter.html', to: "proposeSetParameter.html" },
      { from: './app/proposeCreateMoney.html', to: "proposeCreateMoney.html" },
      { from: './app/proposeDestroyMoney.html', to: "proposeDestroyMoney.html" },
      { from: './app/proposePayCitizen.html', to: "proposePayCitizen.html" },
      { from: './app/proposeFineCitizen.html', to: "proposeFineCitizen.html" },
      { from: './app/proposePackage.html', to: "proposePackage.html" },
      { from: './app/howToJoin.html', to: "howToJoin.html" },
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
