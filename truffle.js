var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "soldier glare isolate submit assault key tiger garden aerobic view hole item";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      gas: 6721974
    }
  },
  compilers: {
    solc: {
      version: "^0.4.25"
    }
  }
};