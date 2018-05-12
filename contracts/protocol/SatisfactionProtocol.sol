pragma solidity ^0.4.23;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

import "../token/SatisfactionToken.sol";
import "./token/BrandedToken.sol";


contract SatisfactionProtocol is Ownable {


  event NewBrand(uint256 id, address indexed token);
  event Withdraw(uint256 token, address indexed from, uint256 value);

  using SafeMath for uint256;

  mapping(uint256 => BrandedToken) internal brandsTokens;
  mapping(uint256 => address) internal brandsOwners;

  uint256[] internal brands;
  SatisfactionToken public satisfactionToken;

  constructor(address _satisfactionToken) public {
    satisfactionToken = SatisfactionToken(_satisfactionToken);
  }

  /**
   * @dev Throws if called by any address other than the protocol.
   */
  modifier onlyBrand(uint256 _id) {
    require(brandsTokens[_id] != address(0));
    require(msg.sender == brandsOwners[_id]);
    _;
  }

  /**
   * @dev Create a new brand in the consortium with his associated token
   *
   * @param _id Id of the brand
   * @param _tokenName Name of the new token
   * @param _tokenSymbol Token Symbol for the new token
   * @return The address of the new token contract
   */
  function createBrand(
    uint256 _id,
    address _owner,
    string _tokenName,
    string _tokenSymbol,
    uint256 _tokenRate) onlyOwner public returns (BrandedToken)
  {
    require(_owner != address(0));
    require(brandsTokens[_id] == address(0));
    require(_tokenRate > 0);

    BrandedToken token = new BrandedToken(address(0), block.number, _tokenName, _tokenSymbol, "1.0.0", _tokenRate, address(this));

    brandsTokens[_id] = token;
    brandsOwners[_id] = _owner;
    brands.push(_id);

    emit NewBrand(_id, token);

    return token;
  }

  /**
   * @dev Updates the number of brand tokens available
   *
   * @param _token Address of the brandedToken
   */
  function mintBrandedToken(BrandedToken _token) public {
    require(_token != address(0));

    uint256 lastBalance = satisfactionToken.balanceOf(_token);
    uint256 totalSupply = _token.totalSupply();
  
    uint256 amount = lastBalance.mul(_token.rate()).div(1000).sub(totalSupply);
    if (amount > 0) {
      _token.mint(_token, amount);
      _token.approve(satisfactionToken);
    }
  }

  function transfer(uint256 _id, address _to, uint256 _value) onlyBrand(_id) public {
    BrandedToken token = brandsTokens[_id];
    token.transferFrom(token, _to, _value);
  }

  function withdraw(uint256 _id, uint256 _value) public {
    require(brandsTokens[_id] != address(0));

    if (msg.sender == brandsOwners[_id]) {
      withdrawForOwner(_id, _value);
    } else {
      withdrawForHolder(_id, _value);
    }

    emit Withdraw(_id, msg.sender, _value);
  }

  /**
    Getters
  */

  function brandedTokenOf(uint256 _id) view public returns (BrandedToken) {
    return brandsTokens[_id];
  }

  function ownerOf(uint256 _id) view public returns (address) {
    return brandsOwners[_id];
  }

  function getBrandsLength() view public returns (uint256) {
    return brands.length;
  }

  function getBrandsAsBytes(uint256 _from, uint256 _to) view public returns (bytes) {
    require(_from >= 0);
    require(_to >= _from);
    require(brands.length >= _to);

    // Size of bytes
    uint256 size = 32 * (_to - _from);
    uint256 counter = 0;
    bytes memory b = new bytes(size);
    for (uint256 x = _from; x < _to; x += 1) {
      uint256 elem = brands[x];
      for (uint y = 0; y < 32; y += 1) {
        b[counter] = byte(uint8(elem / (2 ** (8 * (31 - y)))));
        counter += 1;
      }
    }
    return b;
  }

  /**
    Internals
   */

  function withdrawForOwner(uint256 _id, uint256 _value) internal {
    BrandedToken token = brandsTokens[_id];

    uint256 lastBalance = token.balanceOf(token);
    require(_value <= lastBalance);

    token.burn(token, _value);

    uint256 amount = _value.mul(1000).div(token.rate());
    satisfactionToken.transferFrom(token, msg.sender, amount);
  }

  function withdrawForHolder(uint256 _id, uint256 _value) internal {
    BrandedToken token = brandsTokens[_id];

    uint256 lastBalance = token.balanceOf(msg.sender);
    require(_value <= lastBalance);

    token.burn(msg.sender, _value);

    address brand = brandsOwners[_id];
    uint256 amount = _value.mul(1000).div(token.rate());

    satisfactionToken.burnFrom(token, amount.div(4));
    satisfactionToken.transferFrom(token, brand, amount.div(4));
    satisfactionToken.transferFrom(token, msg.sender, amount.div(2));
  }
}
