// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../ISelfkeyGovernance.sol";

struct PaymentInfo {
    uint256 timestamp;
    bytes32 credentialType;
    bool valid;
}

contract SelfkeyPaymentRegistry is Initializable, AccessControlUpgradeable {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    uint256 public constant TREASURY_WALLET_INDEX = 0;

    event GovernanceContractChanged(address _governanceContractAddress);
    event CredentialPaid(address indexed _address, address tokenAddress, uint _amount);
    event PaymentCancelled(address indexed _address, uint256 timestamp);
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    address public governanceContractAddress;

    // Payment registry
    mapping(address => PaymentInfo[]) private _paymentRegistry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __AccessControl_init();
        _paused = false;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ISSUER_ROLE, msg.sender);
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setGovernanceContract(address _governanceContractAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_governanceContractAddress != address(0), "Invalid governance contract address");
        governanceContractAddress = _governanceContractAddress;
        emit GovernanceContractChanged(governanceContractAddress);
    }

    function payToken(uint _amount, address _tokenContractAddress, bytes32 _credentialType, string memory _couponCode) public whenNotPaused {
        ISelfkeyGovernance governance = ISelfkeyGovernance(governanceContractAddress);
        // bool _paymentEnabled = governance.entryFeeStatus();
        // require(_paymentEnabled == true, "Selfkey Governance: payments are disabled");

        PaymentCurrency memory _currency = governance.getCurrency(_tokenContractAddress);
        require(_currency.active == true, "Selfkey Governance: ERC20 token payment not allowed");
        uint expectedAmount = _currency.amount;

        if (_currency.discount > 0 && _currency.discount <= 100) {
            expectedAmount = (_currency.amount * _currency.discount) / 100;
        }

        Coupons memory _coupon = governance.getValidCoupon(_couponCode, msg.sender);
        // Get coupon if coupon is not empty
        if (_coupon.active == true) {
            require(_coupon.active == true, "Selfkey Governance: invalid coupon");
            require(_coupon.expiry > block.timestamp || _coupon.expiry == 0, "Selfkey Governance: coupon expired");
            uint _couponValue = _selectCouponValue(_coupon, expectedAmount);
            expectedAmount = _couponValue < expectedAmount ? _couponValue : expectedAmount;
        }

        require(_amount >= expectedAmount, "Selfkey Governance: invalid amount");

        require(expectedAmount <= getAllowance(_tokenContractAddress), "not enough allowance");

        address _receiverWallet = governance.addresses(TREASURY_WALLET_INDEX);
        require(_receiverWallet != address(0), "Selfkey Governance: invalid treasury wallet");

        _cancelActivePayments(msg.sender, _credentialType);

        IERC20 token = IERC20(_tokenContractAddress);

        // Transfer affiliate fee
        if (bytes(_couponCode).length > 0 && _coupon.affiliateWallet != address(0)) {
            uint256 _affiliateFee = (_amount * _coupon.affiliateShare) / 100;
            token.transferFrom(msg.sender, _coupon.affiliateWallet, _affiliateFee);
            token.transferFrom(msg.sender, _receiverWallet, _amount - _affiliateFee);
        }
        else {
            token.transferFrom(msg.sender, _receiverWallet, _amount);
        }

        _paymentRegistry[msg.sender].push(PaymentInfo(block.timestamp, _credentialType, true));
        emit CredentialPaid(msg.sender, _tokenContractAddress, _amount);
    }

    function pay(bytes32 _credentialType, string memory _couponCode) public payable whenNotPaused {
        ISelfkeyGovernance governance = ISelfkeyGovernance(governanceContractAddress);
        bool _paymentEnabled = governance.entryFeeStatus();
        require(_paymentEnabled == true, "Selfkey Governance: payments are disabled");

        PaymentCurrency memory _currency = governance.getCurrency(address(0));
        require(_currency.active == true, "Selfkey Governance: native payment not allowed");

        uint expectedAmount = _currency.amount;

        if (_currency.discount > 0 && _currency.discount <= 100) {
            expectedAmount = (_currency.amount * _currency.discount) / 100;
        }

        Coupons memory _coupon = governance.getValidCoupon(_couponCode, msg.sender);
        // Get coupon if coupon is not empty
        if (_coupon.active == true) {
            require(_coupon.active == true, "Selfkey Governance: invalid coupon");
            require(_coupon.expiry > block.timestamp || _coupon.expiry == 0, "Selfkey Governance: coupon expired");
            uint _couponValue = _selectCouponValue(_coupon, expectedAmount);
            expectedAmount = _couponValue < expectedAmount ? _couponValue : expectedAmount;
        }
        require(msg.value >= expectedAmount, "Selfkey Governance: invalid amount");

        address _receiverWallet = governance.addresses(TREASURY_WALLET_INDEX);
        require(_receiverWallet != address(0), "Selfkey Governance: invalid treasury wallet");

        _cancelActivePayments(msg.sender, _credentialType);

         if (bytes(_couponCode).length > 0 && _coupon.affiliateWallet != address(0)) {
            uint256 _affiliateFee = (msg.value * _coupon.affiliateShare) / 100;

            (bool sentAffiliate, ) = _coupon.affiliateWallet.call{value: _affiliateFee}("");
            require(sentAffiliate, "Failed to send Ether to affiliate");

            (bool sent, ) = _receiverWallet.call{value: (msg.value - _affiliateFee)}("");
            require(sent, "Failed to send Ether");

        }
        else {
            (bool sent, ) = _receiverWallet.call{value: msg.value}("");
            require(sent, "Failed to send Ether");
        }

        _paymentRegistry[msg.sender].push(PaymentInfo(block.timestamp, _credentialType, true));
        emit CredentialPaid(msg.sender, address(0), msg.value);
    }


    function _cancelActivePayments(address _address, bytes32 _credentialType) private {
        uint count = _paymentRegistry[_address].length;
        for(uint i=0; i<count; i++) {
            PaymentInfo memory record = _paymentRegistry[_address][i];
            if (record.credentialType == _credentialType && record.valid == true) {
                _paymentRegistry[_address][i].valid = false;
                emit PaymentCancelled(_address, record.timestamp);
            }
        }
    }

    function getAllowance(address _tokenContractAddress) public view returns(uint256) {
        IERC20 token = IERC20(_tokenContractAddress);
        return token.allowance(msg.sender, address(this));
    }

    function getPayments(address _address) external view returns (PaymentInfo[] memory) {
        return _paymentRegistry[_address];
    }

    function cancelPayment(address _address, bytes32 _credentialType, uint256 _timestamp) external onlyRole(ISSUER_ROLE) {
        uint count = _paymentRegistry[_address].length;
        for(uint i=0; i<count; i++) {
            PaymentInfo memory record = _paymentRegistry[_address][i];
            if (record.timestamp == _timestamp && record.credentialType == _credentialType) {
                _paymentRegistry[_address][i].valid = false;
                emit PaymentCancelled(_address, record.timestamp);
            }
        }
    }

    function _selectCouponValue(Coupons memory _coupon, uint256 expectedAmount) private pure returns(uint256) {
        uint expectedFixedAmount = 0;
        uint expectedPercentageAmount = 0;

        if (_coupon.amount > 0 && _coupon.amount <= expectedAmount) {
            expectedFixedAmount = _coupon.amount;
        }
        if (_coupon.discount > 0 && _coupon.discount <= 100) {
            expectedPercentageAmount = (expectedAmount * _coupon.discount) / 100;
        }

            uint lowerExpectedValue = _selectLowerValue(expectedFixedAmount, expectedPercentageAmount);
        return lowerExpectedValue;
    }

    function _selectLowerValue(uint256 _value1, uint256 _value2) private pure returns(uint256) {
        if (_value1 > 0 && _value2 > 0) {
            return _value1 < _value2 ? _value1 : _value2;
        }
        else if (_value1 > 0) {
            return _value1;
        }
        else if (_value2 > 0) {
            return _value2;
        }
        return 0;
    }
}
