const chai = require('chai');

const SatisfactionProtocol = artifacts.require('SatisfactionProtocol');
const SatisfactionToken = artifacts.require('SatisfactionToken');

const BrandedToken = artifacts.require('BrandedToken');

class TokenState {
  constructor (token) {
    this.token = token;
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

function stripHexPrefix (str) {
  return str.startsWith('0x') ? str.slice(2) : str;
}

// Convert byte string to int array.
function bytesToIntArray (byteString) {
  let stripped = stripHexPrefix(byteString);
  return stripped.match(/.{1,64}/g).map(s => parseInt('0x' + s));
}

contract('SatisfactionProtocol', function (accounts) {
  let satisfactionProtocol;
  let satisfactionToken;
  let satisfactionTokenState;
  const b = [];

  describe('creating a valid SatisfactionProtocol', function () {
    before(async () => {});

    it('should deploy all the contracts', async () => {
      satisfactionToken = await SatisfactionToken.new(0, 0, '0.0.1', true);
      assert.ok(satisfactionToken.address);

      satisfactionTokenState = new TokenState(satisfactionToken);

      b[0] = web3.eth.blockNumber;

      const st = await satisfactionTokenState.getState();

      satisfactionProtocol = await SatisfactionProtocol.new(satisfactionToken.address);
      assert.ok(satisfactionProtocol.address);

      log(
        `b[0]-> ${b[0]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${st.balances[accounts[2]]}, ${
          st.balances[accounts[3]]
        }`
      );
    }).timeout(20000);

    it('Should generate 1000 SAT for address 1', async () => {
      await satisfactionToken.mint(accounts[1], web3.toWei('1000', 'ether'));

      b[1] = await web3.eth.blockNumber;

      const st = await satisfactionTokenState.getState();

      assert.equal(st.totalSupply.toNumber(), web3.toWei('1000', 'ether'));
      assert.equal(st.balances[accounts[1]].toNumber(), web3.toWei('1000', 'ether'));

      log(
        `b[1]-> ${b[1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${st.balances[accounts[2]]}, ${
          st.balances[accounts[3]]
        }`
      );
    }).timeout(6000);

    it('Should create new brand "Branded 1"', async () => {
      await satisfactionProtocol.createBrand(10101, accounts[1], 'Branded Token 1', 'BT1', 1000);

      b[1] = await web3.eth.blockNumber;

      const length = await satisfactionProtocol.getBrandsLength();
      assert.equal(length, 1);
    }).timeout(6000);

    it('Should get brands list [10101]', async () => {
      const length = await satisfactionProtocol.getBrandsLength();

      const bytes = await satisfactionProtocol.getBrandsAsBytes(0, length);
      const array = bytesToIntArray(bytes);

      assert.deepEqual(array, [10101]);
    });

    it('Should mint 100 BT1 tokens', async function () {
      const brandedTokenAddress = await satisfactionProtocol.brandedTokenOf(10101);
      const brandedToken = await BrandedToken.at(brandedTokenAddress);

      await satisfactionToken.transfer(brandedTokenAddress, web3.toWei('100', 'ether'), { from: accounts[1] });

      const st = await satisfactionTokenState.getState();
      const balance = await satisfactionToken.balanceOf(brandedTokenAddress);

      assert.equal(st.totalSupply.toNumber(), web3.toWei('1000', 'ether'));
      assert.equal(st.balances[accounts[1]].toNumber(), web3.toWei('900', 'ether'));
      assert.equal(balance.toNumber(), web3.toWei('100', 'ether'));

      let totalSupply = await brandedToken.balanceOf(brandedTokenAddress);

      assert.equal(totalSupply, 0);

      await satisfactionProtocol.mintBrandedToken(brandedTokenAddress);

      totalSupply = await brandedToken.balanceOf(brandedTokenAddress);

      assert.equal(totalSupply.toNumber(), web3.toWei('100', 'ether'));
    });

    it('Should burn 50 BT1 tokens from brand', async function () {
      const brandedTokenAddress = await satisfactionProtocol.brandedTokenOf(10101);
      const brandedToken = await BrandedToken.at(brandedTokenAddress);

      await satisfactionProtocol.withdraw(10101, web3.toWei('50', 'ether'), { from: accounts[1] });

      const st = await satisfactionTokenState.getState();
      const balance = await satisfactionToken.balanceOf(brandedTokenAddress);
      let totalSupply = await brandedToken.totalSupply();

      assert.equal(st.totalSupply.toNumber(), web3.toWei('1000', 'ether'));
      assert.equal(st.balances[accounts[1]].toNumber(), web3.toWei('950', 'ether'));
      assert.equal(balance.toNumber(), web3.toWei('50', 'ether'));
      assert.equal(totalSupply.toNumber(), web3.toWei('50', 'ether'));
    });

    it('Should transfer 30 BT1 tokens to address 2', async function () {
      const brandedTokenAddress = await satisfactionProtocol.brandedTokenOf(10101);
      const brandedToken = await BrandedToken.at(brandedTokenAddress);

      await satisfactionProtocol.transfer(10101, accounts[2], web3.toWei('30', 'ether'), { from: accounts[1] });

      const tokenState = new TokenState(brandedToken);

      const st = await tokenState.getState();
      const balance = await brandedToken.balanceOf(brandedTokenAddress);
      let totalSupply = await brandedToken.totalSupply();

      assert.equal(st.balances[accounts[2]].toNumber(), web3.toWei('30', 'ether'));
      assert.equal(balance.toNumber(), web3.toWei('20', 'ether'));
      assert.equal(totalSupply.toNumber(), web3.toWei('50', 'ether'));
    });

    it('Should burn 20 BT1 tokens from address 2', async function () {
      const brandedTokenAddress = await satisfactionProtocol.brandedTokenOf(10101);
      const brandedToken = await BrandedToken.at(brandedTokenAddress);

      await satisfactionProtocol.withdraw(10101, web3.toWei('20', 'ether'), { from: accounts[2] });

      const st = await satisfactionTokenState.getState();
      let balance = await satisfactionToken.balanceOf(accounts[2]);

      assert.equal(st.totalSupply.toNumber(), web3.toWei('995', 'ether'));
      assert.equal(st.balances[accounts[2]].toNumber(), web3.toWei('10', 'ether'));
      assert.equal(st.balances[accounts[1]].toNumber(), web3.toWei('955', 'ether'));
      assert.equal(balance.toNumber(), web3.toWei('10', 'ether'));

      balance = await satisfactionToken.balanceOf(brandedTokenAddress);
      assert.equal(balance.toNumber(), web3.toWei('30', 'ether'));

      balance = await brandedToken.balanceOf(brandedTokenAddress);
      assert.equal(balance.toNumber(), web3.toWei('20', 'ether'));

      let totalSupply = await brandedToken.totalSupply();
      assert.equal(totalSupply.toNumber(), web3.toWei('30', 'ether'));
    });

    it('Should transfer back 10 BT1 tokens', async function () {
      const brandedTokenAddress = await satisfactionProtocol.brandedTokenOf(10101);
      const brandedToken = await BrandedToken.at(brandedTokenAddress);

      await brandedToken.transfer(brandedTokenAddress, web3.toWei('10', 'ether'), { from: accounts[2] });

      const tokenState = new TokenState(brandedToken);

      const st = await tokenState.getState();
      const balance = await brandedToken.balanceOf(brandedTokenAddress);
      let totalSupply = await brandedToken.totalSupply();

      assert.equal(st.balances[accounts[2]].toNumber(), web3.toWei('0', 'ether'));
      assert.equal(balance.toNumber(), web3.toWei('30', 'ether'));
      assert.equal(totalSupply.toNumber(), web3.toWei('30', 'ether'));
    });
  });
});
