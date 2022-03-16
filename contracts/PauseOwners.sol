// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "./Owners.sol";

contract PauseOwners is Owners {
    bool public isPaused;

    mapping(address => bool) public pauseExempt;

    function pauseGuard(address[3] memory addresses) internal view virtual {
        bool isExempt = false;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (isOwner(addresses[i]) || pauseExempt[addresses[i]]) {
                isExempt = true;
                break;
            }
        }
        require(isExempt, "Paused");
    }

    /// @notice Pause any functions which use checkPaused modifier
    /// @param isPaused_ True to pause false to unpause
    function setIsPaused(bool isPaused_) public onlyOwners {
        isPaused = isPaused_;
    }

    function modifyPauseExempt(address address_, bool value) public onlyOwners {
        pauseExempt[address_] = value;
    }
}
