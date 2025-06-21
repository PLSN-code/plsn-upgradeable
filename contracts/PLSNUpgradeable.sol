// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PLSNUpgradeable is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    // نسبة ضريبة 0.15% (15 نقطة أساس)
    uint256 public taxBasisPoints;
    // محفظة التبرع
    address public donationWallet;
    // محفظة السيولة
    address public liquidityWallet;
    // محفظة التطوير
    address public developmentWallet;

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

        taxBasisPoints = 15; // 0.15% = 15 نقطة أساس
        donationWallet = donationWallet_;
        liquidityWallet = liquidityWallet_;
        developmentWallet = developmentWallet_;

        _mint(msg.sender, initialSupply_ * 10 ** decimals());
    }

    // تعديل محفظة التبرع (للمالك فقط)
    function setDonationWallet(address _wallet) external onlyOwner {
        donationWallet = _wallet;
    }

    // تعديل محفظة السيولة (للمالك فقط)
    function setLiquidityWallet(address _wallet) external onlyOwner {
        liquidityWallet = _wallet;
    }

    // تعديل محفظة التطوير (للمالك فقط)
    function setDevelopmentWallet(address _wallet) external onlyOwner {
        developmentWallet = _wallet;
    }

    // حساب الضريبة من كل معاملة وتحويلها للمحافظ الثلاثة بنسبة متساوية
    function _transfer(address sender, address recipient, uint256 amount) internal override {
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
