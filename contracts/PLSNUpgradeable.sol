// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract PLSNUpgradeable is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    uint256 public taxBasisPoints;
    address public donationWallet;
    address public liquidityWallet;
    address public developmentWallet;

    bool public taxEnabled;
    bool public paused;

    uint256 public launchTime;
    uint256 public updatesAllowedPeriod;

    bool public tradingEnabled;
    uint256 public launchBlock;
    uint256 public botProtectionBlocks;

    mapping(address => bool) public isExcludedFromProtection;
    mapping(address => bool) public isBlacklisted;

    uint256 private _cap;

    modifier onlyDuringUpdatePeriod() {
        require(
            block.timestamp <= launchTime + updatesAllowedPeriod,
            "Updates period expired"
        );
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        address donationWallet_,
        address liquidityWallet_,
        address developmentWallet_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init();
        __ReentrancyGuard_init();

        taxBasisPoints = 15;
        donationWallet = donationWallet_;
        liquidityWallet = liquidityWallet_;
        developmentWallet = developmentWallet_;
        taxEnabled = true;
        paused = false;

        tradingEnabled = false;
        botProtectionBlocks = 5;
        isExcludedFromProtection[msg.sender] = true;

        launchTime = block.timestamp;
        updatesAllowedPeriod = 30 days;

        _cap = 200_000_000 * 10 ** decimals(); // ✅ الحد الأقصى الجديد: 200 مليون
        _mint(msg.sender, initialSupply_ * 10 ** decimals());
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function _mint(address to, uint256 amount) internal override {
        require(totalSupply() + amount <= cap(), "Cap exceeded");
        super._mint(to, amount);
    }

    // == تحديثات قابلة للتعطيل بعد الإطلاق ==
    function setTaxEnabled(bool _enabled) external onlyOwner onlyDuringUpdatePeriod {
        taxEnabled = _enabled;
    }

    function setPaused(bool _paused) external onlyOwner onlyDuringUpdatePeriod {
        paused = _paused;
    }

    function setDonationWallet(address _wallet) external onlyOwner onlyDuringUpdatePeriod {
        donationWallet = _wallet;
    }

    function setLiquidityWallet(address _wallet) external onlyOwner onlyDuringUpdatePeriod {
        liquidityWallet = _wallet;
    }

    function setDevelopmentWallet(address _wallet) external onlyOwner onlyDuringUpdatePeriod {
        developmentWallet = _wallet;
    }

    function setBotProtectionBlocks(uint256 blocks) external onlyOwner onlyDuringUpdatePeriod {
        botProtectionBlocks = blocks;
    }

    function excludeFromProtection(address account, bool excluded) external onlyOwner onlyDuringUpdatePeriod {
        isExcludedFromProtection[account] = excluded;
    }

    function enableTrading() external onlyOwner onlyDuringUpdatePeriod {
        require(!tradingEnabled, "Already enabled");
        tradingEnabled = true;
        launchBlock = block.number;
    }

    // == التحويل مع الحماية والضريبة ==
    function _transfer(address sender, address recipient, uint256 amount) internal override nonReentrant {
        require(!isBlacklisted[sender] && !isBlacklisted[recipient], "Blacklisted");

        if (!isExcludedFromProtection[sender] && !isExcludedFromProtection[recipient]) {
            require(tradingEnabled, "Trading not yet enabled");
            if (block.number <= launchBlock + botProtectionBlocks) {
                revert("Anti-bot: Wait for trading window");
            }
        }

        if (paused || !taxEnabled) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 taxAmount = (amount * taxBasisPoints) / 10000;
        uint256 amountAfterTax = amount - taxAmount;

        if (taxAmount > 0) {
            uint256 share = taxAmount / 3;
            super._transfer(sender, donationWallet, share);
            super._transfer(sender, liquidityWallet, share);
            super._transfer(sender, developmentWallet, taxAmount - 2 * share);
        }

        super._transfer(sender, recipient, amountAfterTax);
    }
}
