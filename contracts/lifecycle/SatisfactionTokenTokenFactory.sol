pragma solidity ^0.4.23;


import "../token/SatisfactionToken.sol";


/**
 * @dev This contract is used to generate clone contracts from a contract.
 *  In solidity this is the way to create a contract from a contract of the
 *  same class
 */
contract SatisfactionTokenFactory {

  event NewCloneToken(address indexed cloneToken, uint256 snapshotBlock);

  /**
   * @notice Update the DApp by creating a new token with new functionalities
   *  the msg.sender becomes the controller of this clone token
   * @param _parentToken Address of the token being cloned
   * @param _snapshotBlock Block of the parent token that will
   *  determine the initial distribution of the clone token
   * @param _transfersEnabled If true, tokens will be able to be transferred
   * @return The address of the new token contract
   */
  function createCloneToken(
    address _parentToken,
    uint256 _snapshotBlock,
    string _tokenVersion,
    bool _transfersEnabled) public returns (SatisfactionToken)
  {
    uint256 snapshotBlock = _snapshotBlock;
    if (_snapshotBlock == 0)
      snapshotBlock = block.number;

    SatisfactionToken cloneToken = new SatisfactionToken(
    _parentToken,
    snapshotBlock,
    _tokenVersion,
    _transfersEnabled);

    cloneToken.transferOwnership(msg.sender);
    emit NewCloneToken(address(cloneToken), _snapshotBlock);
    return cloneToken;
  }
}