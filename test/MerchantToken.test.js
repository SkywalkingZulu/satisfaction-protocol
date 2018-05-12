const chai = require('chai');

const BrandedToken = artifacts.require('BrandedToken');

class BrandedTokenState {
  constructor (brandToken) {
    this.token = brandToken;
  }

  async getState () {
    const st = {
      balances: {},
    };

    const res = await Promise.all([
      this.token.name(),
      this.token.decimals(),
      this.token.owner(),
      this.token.totalSupply(),
      this.token.parentToken(),
      this.token.owner(),
      this.token.parentSnapShotBlock(),
      web3.eth.accounts,
    ]);

    st.name = res[0];
    st.decimals = res[1];
    st.controller = res[2];
    st.totalSupply = res[3];
    st.parentToken = res[4];
    st.controller = res[5];
    st.parentSnapShotBlock = res[6];
    const accounts = res[7];

    const calls = accounts.map(account => this.token.balanceOf(account));

    const balances = await Promise.all(calls);

    for (let i = 0; i < accounts.length; i += 1) {
      st.balances[accounts[i]] = balances[i];
    }

    return st;
  }
}

const assert = chai.assert;

const verbose = false;

const log = S => {
  if (verbose) {
    console.log(S);
  }
};

contract('BrandedToken', function (accounts) {
  let brandToken;
  let brandTokenState;
  let protocol = accounts[6];
  const b = [];

  describe('creating a valid BrandedToken', function () {
    before(async () => {});

    it('Should deploy all the contracts', async () => {
      brandToken = await BrandedToken.new(0, 0, 'Branded Test Token', 'MT', '0.0.1', 100, protocol);
      assert.ok(brandToken.address);
      brandTokenState = new BrandedTokenState(brandToken);

      b[0] = web3.eth.blockNumber;

      const st = await brandTokenState.getState();
      log(
        `b[0]-> ${b[0]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${st.balances[accounts[2]]}, ${
          st.balances[accounts[3]]
        }`
      );
    }).timeout(20000);

    it('Should generate tokens for address 1', async () => {
      await brandToken.mint(accounts[1], 10, { from: protocol });

      b[1] = await web3.eth.blockNumber;

      const st = await brandTokenState.getState();
      assert.equal(st.totalSupply, 10);
      assert.equal(st.balances[accounts[1]], 10);

      log(
        `b[1]-> ${b[1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${st.balances[accounts[2]]}, ${
          st.balances[accounts[3]]
        }`
      );
    }).timeout(6000);

    it('Should Destroy 3 tokens from 1', async () => {
      await brandToken.burn(accounts[1], 3, { from: protocol });

      b[2] = web3.eth.blockNumber;

      const st = await brandTokenState.getState();
      assert.equal(st.totalSupply, 7);
      assert.equal(st.balances[accounts[1]], 7);

      log(
        `b[2]-> ${b[2]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${st.balances[accounts[2]]}, ${
          st.balances[accounts[3]]
        }`
      );
    });
  });
});
