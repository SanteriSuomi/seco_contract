// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "./Owners.sol";

contract PauseOwners is Owners {
    bool public isPaused;

    modifier checkPaused(address address_) {
        if (!isOwner(address_)) {
            require(!isPaused, "Contract paused");
        }
        _;
    }

    /// @notice Pause any functions which use checkPaused modifier
    /// @param isPaused_ True to pause false to unpause
    function setIsPaused(bool isPaused_) public onlyOwners {
        isPaused = isPaused_;
    }
}
