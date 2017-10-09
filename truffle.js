// Allows us to use ES6 in our migrations and tests.
require('babel-register')

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 6700000,
      from: "0x52ec249dd2eec428b1e2f389c7d032caf5d1a238"
    }
  }
}
