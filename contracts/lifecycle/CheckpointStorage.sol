pragma solidity ^0.4.23;


contract CheckpointStorage {

  /**
   * @dev `Checkpoint` is the structure that attaches a block number to a
   * @dev given value, the block number attached is the one that last changed the
   * @dev value
   */
  struct Checkpoint {
    // `fromBlock` is the block number that the value was generated from
    uint128 fromBlock;

    // `value` is the amount of tokens at a specific block number
    uint128 value;
  }

  // Tracks the history of the `totalSupply` of the token
  Checkpoint[] public totalSupplyHistory;

  /**
   * @dev `getValueAt` retrieves the number of tokens at a given block number
   *
   * @param checkpoints The history of values being queried
   * @param _block The block number to retrieve the value at
   * @return The number of tokens being queried
   */
  function getValueAt(Checkpoint[] storage checkpoints, uint _block) internal view returns (uint) {
    if (checkpoints.length == 0)
      return 0;

    // Shortcut for the actual value
    if (_block >= checkpoints[checkpoints.length - 1].fromBlock)
      return checkpoints[checkpoints.length - 1].value;
    if (_block < checkpoints[0].fromBlock)
      return 0;

    // Binary search of the value in the array
    uint min = 0;
    uint max = checkpoints.length - 1;
    while (max > min) {
      uint mid = (max + min + 1) / 2;
      if (checkpoints[mid].fromBlock <= _block) {
        min = mid;
      } else {
        max = mid - 1;
      }
    }
    return checkpoints[min].value;
  }

  /**
   * @dev `updateValueAtNow` used to update the `balances` map and the
   * @dev `totalSupplyHistory`
   *
   * @param checkpoints The history of data being updated
   * @param _value The new number of tokens
   */
  function updateValueAtNow(Checkpoint[] storage checkpoints, uint _value) internal {
    if ((checkpoints.length == 0) || (checkpoints[checkpoints.length - 1].fromBlock < block.number)) {
      Checkpoint storage newCheckPoint = checkpoints[checkpoints.length++];
      newCheckPoint.fromBlock = uint128(block.number);
      newCheckPoint.value = uint128(_value);
    } else {
      Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
      oldCheckPoint.value = uint128(_value);
    }
  }
}