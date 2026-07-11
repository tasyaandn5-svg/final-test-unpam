// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Time-Locked Personal Vault
/// @notice Vault pribadi milik satu owner. ETH yang di-deposit terkunci
///         sampai unlockTime tercapai. Owner bisa memperpanjang (bukan
///         mempersingkat) waktu kunci sebelum ditarik.
contract PersonalVault {
    // Alamat pemilik vault (yang berhak withdraw & extend)
    address public immutable owner;
    // Timestamp kapan dana boleh ditarik
    uint256 public unlockTime;

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);
    event LockExtended(uint256 oldUnlockTime, uint256 newUnlockTime);

    // Custom errors (lebih murah gas & lebih jelas daripada require+string)
    error NotOwner();
    error InvalidUnlockTime();
    error FundsLocked();
    error NoBalance();
    error CannotShortenLock();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param _unlockTime Timestamp (detik) kapan dana boleh ditarik.
    ///        WAJIB di masa depan — ini poin yang paling sering kelewat
    ///        (lihat studi kasus skor 39/100).
    constructor(uint256 _unlockTime) {
        if (_unlockTime <= block.timestamp) revert InvalidUnlockTime();
        owner = msg.sender;
        unlockTime = _unlockTime;
    }

    /// @notice Deposit ETH ke vault. Siapa saja boleh kirim ETH,
    ///         tapi cuma owner yang bisa menariknya nanti.
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Tarik seluruh saldo vault. Hanya owner, hanya setelah unlockTime.
    function withdraw() external onlyOwner {
        if (block.timestamp < unlockTime) revert FundsLocked();
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoBalance();
        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdraw(owner, amount);
    }

    /// @notice Perpanjang waktu kunci. TIDAK BOLEH mempersingkat.
    /// @param newUnlockTime Waktu unlock baru, harus lebih besar dari yang lama.
    function extendLock(uint256 newUnlockTime) external onlyOwner {
        if (newUnlockTime <= unlockTime) revert CannotShortenLock();
        uint256 oldUnlockTime = unlockTime;
        unlockTime = newUnlockTime;
        emit LockExtended(oldUnlockTime, newUnlockTime);
    }

    /// @notice Helper: cek saldo vault saat ini.
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Helper: cek sisa waktu (detik) sebelum bisa withdraw.
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= unlockTime) return 0;
        return unlockTime - block.timestamp;
    }
}
