pragma solidity ^0.4.23;


import "zeppelin-solidity/contracts/math/Math.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

import "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

import "../lifecycle/CheckpointStorage.sol";


contract SatisfactionToken is ERC20, CheckpointStorage, NoOwner {

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  event Mint(address indexed to, uint256 amount);
  event MintFinished();
  event Burn(address indexed burner, uint256 value);

  using SafeMath for uint256;

  string public name = "Satisfaction Token";
  uint8 public decimals = 18;
  string public symbol = "SAT";
  string public version;

  /**
   * `parentToken` is the Token address that was cloned to produce this token;
   *  it will be 0x0 for a token that was not cloned
   */
  SatisfactionToken public parentToken;

  /**
   * `parentSnapShotBlock` is the block number from the Parent Token that was
   *  used to determine the initial distribution of the Clone Token
   */
  uint256 public parentSnapShotBlock;

  // `creationBlock` is the block number that the Clone Token was created
  uint256 public creationBlock;

  /**
   * `balances` is the map that tracks the balance of each address, in this
   *  contract when the balance changes the block number that the change
   *  occurred is also included in the map
   */
  mapping(address => Checkpoint[]) internal balances;

  // `allowed` tracks any extra transfer rights as in all ERC20 tokens
  mapping(address => mapping(address => uint256)) internal allowed;

  // Flag that determines if the token is transferable or not.
  bool public transfersEnabled;

  bool public mintingFinished = false;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  constructor(
    address _parentToken,
    uint256 _parentSnapShotBlock,
    string _tokenVersion,
    bool _transfersEnabled) public
  {
    version = _tokenVersion;
    parentToken = SatisfactionToken(_parentToken);
    parentSnapShotBlock = _parentSnapShotBlock;
    transfersEnabled = _transfersEnabled;
    creationBlock = block.number;
  }

  /**
   * @dev Transfer token for a specified address
   *
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amout of tokens to be transfered
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(transfersEnabled);
    require(parentSnapShotBlock < block.number);
    require(_to != address(0));

    uint256 lastBalance = balanceOfAt(msg.sender, block.number);
    require(_value <= lastBalance);

    return doTransfer(msg.sender, _to, _value, lastBalance);
  }

  /**
   * @dev Addition to ERC20 token methods. Transfer tokens to a specified
   * @dev address and execute a call with the sent data on the same transaction
   *
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amout of tokens to be transfered
   * @param _data ABI-encoded contract call to call `_to` address.
   *
   * @return true if the call function was executed successfully
   */
  function transferAndCall(address _to, uint256 _value, bytes _data) public payable returns (bool) {
    require(_to != address(this));

    transfer(_to, _value);

    // solium-disable-next-line security/no-call-value
    require(_to.call.value(msg.value)(_data));
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another
   *
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(transfersEnabled);
    require(parentSnapShotBlock < block.number);
    require(_to != address(0));
    require(_value <= allowed[_from][msg.sender]);

    uint256 lastBalance = balanceOfAt(_from, block.number);
    require(_value <= lastBalance);

    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

    return doTransfer(_from, _to, _value, lastBalance);
  }

  /**
   * @dev Addition to ERC20 token methods. Transfer tokens from one address to
   * @dev another and make a contract call on the same transaction
   *
   * @param _from The address which you want to send tokens from
   * @param _to The address which you want to transfer to
   * @param _value The amout of tokens to be transferred
   * @param _data ABI-encoded contract call to call `_to` address.
   *
   * @return true if the call function was executed successfully
   */
  function transferFromAndCall(
    address _from,
    address _to,
    uint256 _value,
    bytes _data
  )
    public payable returns (bool)
  {
    require(_to != address(this));

    transferFrom(_from, _to, _value);

    // solium-disable-next-line security/no-call-value
    require(_to.call.value(msg.value)(_data));
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   *
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * @dev approve should be called when allowed[_spender] == 0. To increment
   * @dev allowed value is better to use this function to avoid 2 calls (and wait until
   * t@dev he first transaction is mined)
   * @dev From MonolithDAO Token.sol
   *
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Addition to StandardToken methods. Increase the amount of tokens that
   * @dev an owner allowed to a spender and execute a call with the sent data.
   *
   * @dev approve should be called when allowed[_spender] == 0. To increment
   * @dev allowed value is better to use this function to avoid 2 calls (and wait until
   * @dev the first transaction is mined)
   * @dev From MonolithDAO Token.sol
   *
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   * @param _data ABI-encoded contract call to call `_spender` address.
   */
  function increaseApprovalAndCall(address _spender, uint _addedValue, bytes _data) public payable returns (bool) {
    require(_spender != address(this));

    increaseApproval(_spender, _addedValue);

    // solium-disable-next-line security/no-call-value
    require(_spender.call.value(msg.value)(_data));

    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * @dev approve should be called when allowed[_spender] == 0. To decrement
   * @dev allowed value is better to use this function to avoid 2 calls (and wait until
   * @dev the first transaction is mined)
   * @dev From MonolithDAO Token.sol
   *
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Addition to StandardToken methods. Decrease the amount of tokens that
   * @dev an owner allowed to a spender and execute a call with the sent data.
   *
   * @dev approve should be called when allowed[_spender] == 0. To decrement
   * @dev allowed value is better to use this function to avoid 2 calls (and wait until
   * @dev the first transaction is mined)
   * @dev From MonolithDAO Token.sol
   *
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   * @param _data ABI-encoded contract call to call `_spender` address.
   */
  function decreaseApprovalAndCall(address _spender, uint _subtractedValue, bytes _data) public payable returns (bool) {
    require(_spender != address(this));

    decreaseApproval(_spender, _subtractedValue);

    // solium-disable-next-line security/no-call-value
    require(_spender.call.value(msg.value)(_data));

    return true;
  }

  /**
   * @param _owner The address that's balance is being requested
   * @return The balance of `_owner` at the current block
   */
  function balanceOf(address _owner) public view returns (uint256) {
    return balanceOfAt(_owner, block.number);
  }

  /**
   * @dev Queries the balance of `_owner` at a specific `_blockNumber`
   *
   * @param _owner The address from which the balance will be retrieved
   * @param _blockNumber The block number when the balance is queried
   * @return The balance at `_blockNumber`
   */
  function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256) {
    // These next few lines are used when the balance of the token is
    //  requested before a check point was ever created for this token, it
    //  requires that the `parentToken.balanceOfAt` be queried at the
    //  genesis block for that token as this contains initial balance of
    //  this token
    if ((balances[_owner].length == 0) || (balances[_owner][0].fromBlock > _blockNumber)) {
      if (address(parentToken) != address(0)) {
        return parentToken.balanceOfAt(_owner, Math.min256(_blockNumber, parentSnapShotBlock));
      } else {
        // Has no parent
        return 0;
      }
    // This will return the expected balance during normal situations
    } else {
      return getValueAt(balances[_owner], _blockNumber);
    }
  }

  /**
   * @dev This function makes it easy to get the total number of tokens
   *
   * @return The total number of tokens
   */
  function totalSupply() public view returns (uint256) {
    return totalSupplyAt(block.number);
  }

  /**
   * @dev Total amount of tokens at a specific `_blockNumber`.
   *
   * @param _blockNumber The block number when the totalSupply is queried
   * @return The total amount of tokens at `_blockNumber`
   */
  function totalSupplyAt(uint256 _blockNumber) public view returns(uint256) {

    // These next few lines are used when the totalSupply of the token is
    //  requested before a check point was ever created for this token, it
    //  requires that the `parentToken.totalSupplyAt` be queried at the
    //  genesis block for this token as that contains totalSupply of this
    //  token at this block number.
    if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
      if (address(parentToken) != 0) {
        return parentToken.totalSupplyAt(Math.min256(_blockNumber, parentSnapShotBlock));
      } else {
        return 0;
      }
    // This will return the expected totalSupply during normal situations
    } else {
      return getValueAt(totalSupplyHistory, _blockNumber);
    }
  }

  /**
   * @dev Function to mint tokens
   *
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
    uint256 curTotalSupply = totalSupply();
    uint256 lastBalance = balanceOf(_to);

    updateValueAtNow(totalSupplyHistory, curTotalSupply.add(_amount));
    updateValueAtNow(balances[_to], lastBalance.add(_amount));

    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
    return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   *
   * @return True if the operation was successful.
   */
  function finishMinting() public onlyOwner canMint returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }

  /**
   * @dev Burns a specific amount of tokens.
   *
   * @param _value uint256 The amount of token to be burned.
   */
  function burn(uint256 _value) public {
    uint256 lastBalance = balanceOf(msg.sender);
    require(_value <= lastBalance);

    address burner = msg.sender;
    uint256 curTotalSupply = totalSupply();

    updateValueAtNow(totalSupplyHistory, curTotalSupply.sub(_value));
    updateValueAtNow(balances[burner], lastBalance.sub(_value));

    emit Burn(burner, _value);
  }

  /**
   * @dev Burns a specific amount of tokens from an address
   *
   * @param _from address The address which you want to send tokens from
   * @param _value uint256 The amount of token to be burned.
   */
  function burnFrom(address _from, uint256 _value) public {
    require(_value <= allowed[_from][msg.sender]);

    uint256 lastBalance = balanceOfAt(_from, block.number);
    require(_value <= lastBalance);

    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

    address burner = _from;
    uint256 curTotalSupply = totalSupply();

    updateValueAtNow(totalSupplyHistory, curTotalSupply.sub(_value));
    updateValueAtNow(balances[burner], lastBalance.sub(_value));

    emit Burn(burner, _value);
  }

  /**
   * @dev Enables token holders to transfer their tokens freely if true
   *
   * @param _transfersEnabled True if transfers are allowed in the clone
   */
  function enableTransfers(bool _transfersEnabled) public onlyOwner canMint {
    transfersEnabled = _transfersEnabled;
  }

  /**
   * @dev This is the actual transfer function in the token contract, it can
   * @dev only be called by other functions in this contract.
   *
   * @param _from The address holding the tokens being transferred
   * @param _to The address of the recipient
   * @param _value The amount of tokens to be transferred
   * @param _lastBalance The last balance of from
   * @return True if the transfer was successful
   */
  function doTransfer(address _from, address _to, uint256 _value, uint256 _lastBalance) internal returns (bool) {
    if (_value == 0) {
      return true;
    }

    updateValueAtNow(balances[_from], _lastBalance.sub(_value));

    uint256 previousBalance = balanceOfAt(_to, block.number);
    updateValueAtNow(balances[_to], previousBalance.add(_value));

    emit Transfer(_from, _to, _value);
    return true;
  }
}
