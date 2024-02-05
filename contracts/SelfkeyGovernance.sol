// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ISelfkeyGovernance.sol";
import "./external/ISelfkeyDaoVoting.sol";

contract SelfkeyGovernance is ISelfkeyGovernance, Initializable, OwnableUpgradeable  {

    bool public entryFeeStatus;
    mapping (address => PaymentCurrency) private _currencies;
    address[] private _currencyEntries;

    mapping(uint256 => address) public addresses;
    mapping(uint256 => uint256) public numbers;
    mapping(uint256 => bytes32) public data;

    mapping(uint256 => Coupons) public coupons;

    ISelfkeyDaoVoting public daoVotingContract;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    function setEntryFreeStatus(bool _status) public onlyOwner {
        entryFeeStatus = _status;
        emit EntryFeeStatusUpdated(_status);
    }

    function updatePaymentCurrency(string memory _name, address _tokenAddress, uint8 _decimals, uint256 _amount, bool _native, bool _active, uint256 _discount) public onlyOwner {
        if (!currencyExists(_tokenAddress)) {
            _currencyEntries.push(_tokenAddress);
        }
        _currencies[_tokenAddress] = PaymentCurrency(_name, _tokenAddress, _decimals, _amount, _native, _active, _discount);
        emit PaymentCurrencyUpdated(_name, _tokenAddress, _decimals, _amount, _native, _active, _discount);
    }

    function getCurrencies() external view returns (PaymentCurrency[] memory) {
        uint _count = _currencyEntries.length;
        PaymentCurrency[] memory _activeCurrencies = new PaymentCurrency[](_count);
        for(uint i=0; i<_count; i++) {
            PaymentCurrency memory record = _currencies[_currencyEntries[i]];
             _activeCurrencies[i] = record;
        }
        return _activeCurrencies;
    }

    function getCurrency(address _tokenAddress) external view returns (PaymentCurrency memory) {
        return _currencies[_tokenAddress];
    }

    function setAddress(uint256 addressIndex, address newAddress) public onlyOwner {
        address oldAddress = addresses[addressIndex];
        addresses[addressIndex] = newAddress;
        emit AddressUpdated(msg.sender, addressIndex, oldAddress, newAddress);
    }

    function setNumber(uint256 index, uint256 newNumber) public onlyOwner {
        uint256 oldNumber = numbers[index];
        numbers[index] = newNumber;
        emit NumberUpdated(msg.sender, index, oldNumber, newNumber);
    }

    function setData(uint256 index, bytes32 newData) public onlyOwner {
        bytes32 oldData = data[index];
        data[index] = newData;
        emit DataUpdated(msg.sender, index, oldData, newData);
    }

    function currencyExists(address _tokenAddress) private view returns (bool) {
        uint _count = _currencyEntries.length;
        for (uint i = 0; i < _count; i++) {
            if (_currencies[_currencyEntries[i]].tokenAddress == _tokenAddress) {
                return true;
            }
        }
        return false;
    }

    function setCoupon(string memory _coupon, uint256 _discount, uint256 _expiry, bool _active, address _wallet, address _affiliateWallet, uint256 _affiliateShare) public onlyOwner {
        coupons[uint256(keccak256(abi.encodePacked(_coupon)))] = Coupons(_coupon, _discount, 0, _expiry, _active, _wallet, _affiliateWallet, _affiliateShare);
    }

    function getCoupon(string memory _coupon) public view returns (Coupons memory) {
        return coupons[uint256(keccak256(abi.encodePacked(_coupon)))];
    }

    function removeCoupon(string memory _coupon) public onlyOwner {
        delete coupons[uint256(keccak256(abi.encodePacked(_coupon)))];
    }

    function getValidCoupon(string memory _couponCode, address _wallet) public view returns (Coupons memory) {
        Coupons memory _coupon = coupons[uint256(keccak256(abi.encodePacked(_couponCode)))];

        if (!_coupon.active || (_coupon.expiry > 0 && _coupon.expiry < block.timestamp)) {
            return Coupons("", 0, 0, 0, false, address(0), address(0), 0);
        }
        if (_coupon.wallet != address(0)) {
            if (_coupon.wallet != _wallet) {
                return Coupons("", 0, 0, 0, false, address(0), address(0), 0);
            }
        }
        return _coupon;
    }

    function setDaoVotingContractAddress(address _newDaoVotingContractAddress) public onlyOwner {
        daoVotingContract = ISelfkeyDaoVoting(_newDaoVotingContractAddress);
    }

    function isSelfMintingUnlocked() public view returns (bool) {
        uint256 _votingProposalId = numbers[0];
        uint256 _selfUnlockLimit = numbers[1];
        uint256 _numberOfVotes = daoVotingContract.getVoteCount(_votingProposalId);

        return _numberOfVotes >= _selfUnlockLimit;
    }
}
