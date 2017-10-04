// Allows us to use ES6 in our migrations and tests.
require('babel-register')

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 6700000
    },
    ropsten: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 6700000,
      from: "0x553476d38184F03C12255f639Eab1D7b57535d16"
    },
    kovan: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 6700000,
      from: "0x553476d38184F03C12255f639Eab1D7b57535d16"
    }
  }
}
