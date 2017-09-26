// Allows us to use ES6 in our migrations and tests.
require('babel-register')

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 6000000
    },
    geth_dev: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 6000000,
      from: "0x553476d38184F03C12255f639Eab1D7b57535d16"
    }
  }
}
