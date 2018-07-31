require('dotenv').config();
require('babel-register');
require('babel-polyfill');

const HDWalletProvider = require('truffle-hdwallet-provider');
const LedgerWalletProvider = require('truffle-ledger-provider');

const providerWithMnemonic = (mnemonic, rpcEndpoint) => new HDWalletProvider(mnemonic, rpcEndpoint);

const infuraProvider = network =>
  providerWithMnemonic(process.env.MNEMONIC || '', `https://${network}.infura.io/${process.env.INFURA_API_KEY}`);

const ropstenProvider = process.env.SOLIDITY_COVERAGE ? undefined : infuraProvider('ropsten');

const ledgerOptions = {
  networkId: 1,
  path: '44\'/60\'/1\'/0',
  askConfirm: false,
  accountsLength: 1,
  accountsOffset: 0,
};

module.exports = {
  solc: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // eslint-disable-line camelcase
    },
    ropsten: {
      provider: ropstenProvider,
      gas: 4698712,
      network_id: 3, // eslint-disable-line camelcase
    },
    coverage: {
      host: 'localhost',
      network_id: '*', // eslint-disable-line camelcase
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01,
    },
    testrpc: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // eslint-disable-line camelcase
    },
    ganache: {
      host: 'localhost',
      port: 7545,
      network_id: '*', // eslint-disable-line camelcase
    },
    ledger: {
      provider: new LedgerWalletProvider(ledgerOptions, `https://mainnet.infura.io/${process.env.INFURA_API_KEY}`),
      network_id: 1, // eslint-disable-line camelcase
      gasPrice: 20000000000,
    },
  },
};
