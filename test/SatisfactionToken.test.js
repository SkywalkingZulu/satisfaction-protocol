var BigNumber = web3.BigNumber;
require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const Message = artifacts.require('MessageHelper');
const SatisfactionToken = artifacts.require('SatisfactionToken');
const SatisfactionTokenFactory = artifacts.require('SatisfactionTokenFactory');

class SatisfactionTokenState {
  constructor (minimeToken) {
    this.token = minimeToken;
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

const verbose = false;

const log = S => {
  if (verbose) {
    console.log(S);
  }
};

// b[0]  ->  0, 0, 0, 0
// b[1]  ->  0,10, 0, 0
// b[2]  ->  0, 8, 2, 0
// b[3]  ->  0, 9, 1, 0
// b[4]  ->  0, 6, 1, 0
// b[5]  ->  0, 6, 0, 0
//  Clone token
// b[6]  ->  0, 6, 0, 0
// b[7]  ->  0, 1, 5, 0

contract('SatisfactionToken', function (accounts) {
  let tokenFactory;
  let satisfactionToken;
  let satisfactionTokenState;
  let satisfactionTokenClone;
  let satisfactionTokenCloneState;
  const b = [];

  describe('creating a valid SatisfactionToken', function () {
    before(async () => {});

    it('Should deploy all the contracts', async () => {
      tokenFactory = await SatisfactionTokenFactory.new();
      satisfactionToken = await SatisfactionToken.new(0, 0, '0.0.1', true);
      assert.ok(satisfactionToken.address);
      satisfactionTokenState = new SatisfactionTokenState(satisfactionToken);

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenState.getState();
      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    }).timeout(20000);

    it('Should generate tokens for address 1', async () => {
      await satisfactionToken.mint(accounts[1], 10);

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenState.getState();
      assert.equal(st.totalSupply, 10);
      assert.equal(st.balances[accounts[1]], 10);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    }).timeout(6000);

    it('Should transfer tokens from address 1 to address 2', async () => {
      await satisfactionToken.transfer(accounts[2], 2, { from: accounts[1], gas: 200000 });

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenState.getState();
      assert.equal(st.totalSupply, 10);
      assert.equal(st.balances[accounts[1]], 8);
      assert.equal(st.balances[accounts[2]], 2);

      const balance = await satisfactionToken.balanceOfAt(accounts[1], b[1]);
      assert.equal(balance, 10);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    }).timeout(6000);

    it('Should allow and transfer tokens from address 2 to address 1 allowed to 3', async () => {
      await satisfactionToken.approve(accounts[3], 2, { from: accounts[2] });
      const allowed = await satisfactionToken.allowance(accounts[2], accounts[3]);
      assert.equal(allowed, 2);

      await satisfactionToken.transferFrom(accounts[2], accounts[1], 1, { from: accounts[3] });

      const allowed2 = await satisfactionToken.allowance(accounts[2], accounts[3]);
      assert.equal(allowed2, 1);

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenState.getState();
      assert.equal(st.totalSupply, 10);
      assert.equal(st.balances[accounts[1]], 9);
      assert.equal(st.balances[accounts[2]], 1);

      let balance;

      balance = await satisfactionToken.balanceOfAt(accounts[1], b[2]);
      assert.equal(balance, 8);
      balance = await satisfactionToken.balanceOfAt(accounts[2], b[2]);
      assert.equal(balance, 2);
      balance = await satisfactionToken.balanceOfAt(accounts[1], b[1]);
      assert.equal(balance, 10);
      balance = await satisfactionToken.balanceOfAt(accounts[2], b[1]);
      assert.equal(balance, 0);
      balance = await satisfactionToken.balanceOfAt(accounts[1], b[0]);
      assert.equal(balance, 0);
      balance = await satisfactionToken.balanceOfAt(accounts[2], b[0]);
      assert.equal(balance, 0);
      balance = await satisfactionToken.balanceOfAt(accounts[1], 0);
      assert.equal(balance, 0);
      balance = await satisfactionToken.balanceOfAt(accounts[2], 0);
      assert.equal(balance, 0);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    });

    it('Should destroy 3 tokens from 1', async () => {
      await satisfactionToken.burn(3, { from: accounts[1], gas: 200000 });

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenState.getState();
      assert.equal(st.totalSupply, 7);
      assert.equal(st.balances[accounts[1]], 6);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    });

    it('Should destroy 1 tokens from 2 allowed to 3', async () => {
      await satisfactionToken.burnFrom(accounts[2], 1, { from: accounts[3], gas: 200000 });

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenState.getState();
      assert.equal(st.totalSupply, 6);
      assert.equal(st.balances[accounts[2]], 0);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    });

    it('Should Create the clone token', async () => {
      const satisfactionTokenCloneTx = await tokenFactory.createCloneToken(satisfactionToken.address, 0, '0.0.2', true);

      const eventNewCloneToken = satisfactionTokenCloneTx.logs[satisfactionTokenCloneTx.logs.length - 1];

      let addr = eventNewCloneToken.args.cloneToken;
      satisfactionTokenClone = new SatisfactionToken(addr);

      satisfactionTokenCloneState = new SatisfactionTokenState(satisfactionTokenClone);

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenCloneState.getState();

      assert.equal(st.parentToken, satisfactionToken.address);
      assert.equal(st.parentSnapShotBlock, b[6]);
      assert.equal(st.totalSupply, 6);
      assert.equal(st.balances[accounts[1]], 6);

      const totalSupply = await satisfactionTokenClone.totalSupplyAt(b[5]);

      assert.equal(totalSupply, 6);

      const balance = await satisfactionTokenClone.balanceOfAt(accounts[2], b[5]);
      assert.equal(balance, 0);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    }).timeout(6000);

    it('Should mine one block to take effect clone', async () => {
      await satisfactionToken.transfer(accounts[1], 1, { from: accounts[1] });
    });

    it('Should move tokens in the clone token from 1 to 2', async () => {
      await satisfactionTokenClone.transfer(accounts[2], 5, { from: accounts[1] });

      b.push(web3.eth.blockNumber);

      const st = await satisfactionTokenCloneState.getState();
      assert.equal(st.totalSupply, 6);
      assert.equal(st.balances[accounts[1]], 1);
      assert.equal(st.balances[accounts[2]], 5);

      let balance;

      balance = await satisfactionToken.balanceOfAt(accounts[1], b[6]);
      assert.equal(balance, 6);
      balance = await satisfactionToken.balanceOfAt(accounts[2], b[6]);
      assert.equal(balance, 0);
      balance = await satisfactionTokenClone.balanceOfAt(accounts[1], b[6]);
      assert.equal(balance, 6);
      balance = await satisfactionTokenClone.balanceOfAt(accounts[2], b[6]);
      assert.equal(balance, 0);
      balance = await satisfactionTokenClone.balanceOfAt(accounts[1], b[5]);
      assert.equal(balance, 6);
      balance = await satisfactionTokenClone.balanceOfAt(accounts[2], b[5]);
      assert.equal(balance, 0);

      let totalSupply;
      totalSupply = await satisfactionTokenClone.totalSupplyAt(b[6]);
      assert.equal(totalSupply, 6);
      totalSupply = await satisfactionTokenClone.totalSupplyAt(b[5]);
      assert.equal(totalSupply, 6);

      log(
        `b[${b.length - 1}]-> ${b[b.length - 1]}: ${st.balances[accounts[0]]}, ${st.balances[accounts[1]]}, ${
          st.balances[accounts[2]]
        }, ${st.balances[accounts[3]]}`
      );
    }).timeout(6000);

    it('Should create tokens in the child token', async () => {
      await satisfactionTokenClone.mint(accounts[1], 10, { from: accounts[0], gas: 300000 });
      const st = await satisfactionTokenCloneState.getState();
      assert.equal(st.totalSupply, 16);
      assert.equal(st.balances[accounts[1]], 11);
      assert.equal(st.balances[accounts[2]], 5);
    });

    it('Should allow payment through transfer', async function () {
      const message = await Message.new();

      const extraData = message.contract.buyMessage.getData(web3.toHex(123456), 666, 'Transfer Done');

      const transaction = await satisfactionToken.transferAndCall(message.contract.address, 6, extraData, {
        from: accounts[1],
        value: 10,
      });

      assert.equal(2, transaction.receipt.logs.length);

      new BigNumber(6).should.be.bignumber.equal(await satisfactionToken.balanceOf(message.contract.address));
      new BigNumber(10).should.be.bignumber.equal(await web3.eth.getBalance(message.contract.address));
    });
  });
});
