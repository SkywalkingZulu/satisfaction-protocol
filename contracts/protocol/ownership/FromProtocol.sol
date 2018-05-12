pragma solidity ^0.4.23;


/**
 * @title FromProtocol
 * @dev The FromProtocol contract has an protocol address, and provides basic authorization control
 * @dev functions, this simplifies the implementation of "user permissions".
 */
contract FromProtocol {

  event ProtocolTransferred(address indexed previousProtocol, address indexed newProtocol);

  address public protocol;

  /**
   * @dev The FromProtocol constructor sets the original `protocol`
   * @dev account.
   */
  constructor(address _protocol) public {
    require(_protocol != address(0));

    protocol = _protocol;
  }


  /**
   * @dev Throws if called by any address other than the protocol.
   */
  modifier onlyProtocol() {
    require(msg.sender == protocol);
    _;
  }


  /**
   * @dev Allows the current protocol to transfer control of the contract to a newProtocol
   *
   * @param _newProtocol The address of the new protocol.
   */
  function transferProtocol(address _newProtocol) onlyProtocol public {
    require(_newProtocol != address(0));
    emit ProtocolTransferred(protocol, _newProtocol);
    protocol = _newProtocol;
  }

}
