pragma solidity ^0.4.23;


import "zeppelin-solidity/contracts/math/Math.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

import "zeppelin-solidity/contracts/ownership/NoOwner.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

import "../../lifecycle/CheckpointStorage.sol";
import "../ownership/FromProtocol.sol";


contract BrandedToken is ERC20Basic, CheckpointStorage, NoOwner, FromProtocol {

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Mint(address indexed to, uint256 amount);
  event Burn(address indexed burner, uint256 value);

  using SafeMath for uint256;

  string public name;
  uint8 public decimals = 18;
  string public symbol;
  string public version;

  // 1 token = (rate / 1000) SAT
  uint256 public rate;

  /**
   * `parentToken` is the Token address that was cloned to produce this token;
   *  it will be 0x0 for a token that was not cloned
   */
  BrandedToken public parentToken;

  // `parentSnapShotBlock` is the block number from the Parent Token that was
  //  used to determine the initial distribution of the Clone Token
  uint256 public parentSnapShotBlock;

  // `creationBlock` is the block number that the Clone Token was created
  uint256 public creationBlock;

  /**
   * `balances` is the map that tracks the balance of each address, in this
   *  contract when the balance changes the block number that the change
   *  occurred is also included in the map
   */
  mapping(address => Checkpoint[]) internal balances;

  constructor(
    address _parentToken,
    uint256 _parentSnapShotBlock,
    string _tokenName,
    string _tokenSymbol,
    string _tokenVersion,
    uint256 _tokenRate,
    address _protocol)
    FromProtocol(_protocol) public
  {
    name = _tokenName;
    symbol = _tokenSymbol;
    version = _tokenVersion;
    rate = _tokenRate;
    parentToken = BrandedToken(_parentToken);
    parentSnapShotBlock = _parentSnapShotBlock;
    creationBlock = block.number;
  }

  /**
  * @dev transfer token to the brand
  *
  * @param _to Keeps this parameter to comply with ERC20 standard
  * @param _value The amount to be transferred
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(parentSnapShotBlock < block.number);
    require(_to == address(this));

    uint256 lastBalance = balanceOfAt(msg.sender, block.number);
    require(_value <= lastBalance);

    return doTransfer(msg.sender, _to, _value, lastBalance);
  }

  /**
   * @dev Transfer tokens from one address to another
   *
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) onlyProtocol public returns (bool) {
    require(parentSnapShotBlock < block.number);
    require(_to != address(0));

    uint256 lastBalance = balanceOfAt(_from, block.number);
    require(_value <= lastBalance);

    return doTransfer(_from, _to, _value, lastBalance);
  }

  /**
   * @param _owner The address that's balance is being requested
   * @return The balance of `_owner` at the current block
   */
  function balanceOf(address _owner) public view returns (uint256) {
    return balanceOfAt(_owner, block.number);
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
  function mint(address _to, uint256 _amount) onlyProtocol public returns (bool) {
    uint256 curTotalSupply = totalSupply();
    uint256 lastBalance = balanceOf(_to);

    updateValueAtNow(totalSupplyHistory, curTotalSupply.add(_amount));
    updateValueAtNow(balances[_to], lastBalance.add(_amount));

    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
    return true;
  }

  /**
   * @dev Burns a specific amount of tokens.
   *
   * @param _from The address holding the tokens being burned
   * @param _value The amount of token to be burned.
   */
  function burn(address _from, uint256 _value) onlyProtocol public {
    uint256 lastBalance = balanceOf(_from);
    require(_value <= lastBalance);

    uint256 curTotalSupply = totalSupply();

    updateValueAtNow(totalSupplyHistory, curTotalSupply.sub(_value));
    updateValueAtNow(balances[_from], lastBalance.sub(_value));

    emit Burn(_from, _value);
  }

  function approve(ERC20 token) onlyProtocol public {
    uint256 balance = token.balanceOf(this);
    token.approve(protocol, balance);
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
