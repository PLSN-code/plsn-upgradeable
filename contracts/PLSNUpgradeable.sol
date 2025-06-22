// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PLSNUpgradeable is Initializable, ERC20Upgradeable, ERC20CappedUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public taxBasisPoints;
    address public donationWallet;
    address public liquidityWallet;
    address public developmentWallet;

    bool public taxEnabled;
    bool public paused;

    // وقت الإطلاق ومدة التحديث
    uint256 public launchTime;
    uint256 public updatesAllowedPeriod;

    modifier onlyDuringUpdatePeriod() {
        require(block.timestamp <= launchTime + updatesAllowedPeriod, "Updates locked");
        _;
    }

    // الحماية من البوتات
    bool public tradingEnabled;
    uint256 public launchBlock;
    uint256 public botProtectionBlocks;
    mapping(address => bool) public isExcludedFromProtection;
    mapping(address => bool) public isBlacklisted;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
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
        __ERC20Capped_init(100_000_000 * 10 ** decimals()); // حد أقصى 100 مليون
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

        _mint(msg.sender, initialSupply_ * 10 ** decimals());
    }

    // == التعديلات خلال فترة السماح ==
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

    // == التحويل ==
    function _transfer(address sender, address recipient, uint256 amount) internal override nonReentrant {
        require(!isBlacklisted[sender] && !isBlacklisted[recipient], "Blacklisted");

        if (!isExcludedFromProtection[sender] && !isExcludedFromProtection[recipient]) {
            require(tradingEnabled, "Trading not enabled");
            if (block.number <= launchBlock + botProtectionBlocks) {
                revert("Anti-bot: Wait");
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

    // == سك التوكن مع احترام الحد الأقصى ==
    function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._mint(to, amount);
    }

