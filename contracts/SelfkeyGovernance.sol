// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SelfkeyGovernance is Ownable {
  mapping(uint256 => address) public addresses;
  mapping(uint256 => uint256) public numbers;
  mapping(uint256 => bytes32) public data;

  event AddressUpdated(address owner, uint256 index, address oldValue, address newValue);
  event NumberUpdated(address owner, uint256 index, uint256 oldValue, uint256 newValue);
  event DataUpdated(address owner, uint256 index, bytes32 oldValue, bytes32 newValue);

  function setAddress(uint256 addressIndex, address newAddress) public onlyOwner {
    emit AddressUpdated(msg.sender, addressIndex, addresses[addressIndex], newAddress);
    addresses[addressIndex] = newAddress;
  }

  function setNumber(uint256 index, uint256 newNumber) public onlyOwner {
    emit NumberUpdated(msg.sender, index, numbers[index], newNumber);
    numbers[index] = newNumber;
  }

  function setData(uint256 index, bytes32 newData) public onlyOwner {
    emit DataUpdated(msg.sender, index, data[index], newData);
    data[index] = newData;
  }
}
