// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

contract Owners {
    event OwnerAdded(
        address indexed adder,
        address indexed owner,
        uint256 indexed timestamp
    );

    event OwnerRemoved(
        address indexed remover,
        address indexed owner,
        uint256 indexed timestamp
    );

    event OwnershipRenounced(uint256 timestamp);

    bool public renounced;

    address private masterOwner;
    mapping(address => bool) private ownerMap;
    address[] private ownerList;

    constructor() {
        masterOwner = msg.sender;
        ownerMap[msg.sender] = true;
        ownerList.push(msg.sender);
    }

    modifier onlyMasterOwner() {
        require(!renounced, "Ownership renounced");
        require(msg.sender == masterOwner);
        _;
    }

    modifier onlyOwners() {
        require(!renounced, "Ownership renounced");
        require(ownerMap[msg.sender], "Caller is not an owner");
        _;
    }

    /// @notice Return whether given address is one of the owners of this contract
    /// @param address_ Address to check
    /// @return True/False
    function isOwner(address address_) public view returns (bool) {
        return ownerMap[address_];
    }

    /// @notice Get all addresses of current owners
    /// @return List of owners
    function getOwners() external view returns (address[] memory) {
        return ownerList;
    }

    /// @notice Add a new owner, only the master owner can add
    /// @param address_ Address to add
    function addOwner(address address_) public onlyMasterOwner {
        ownerMap[address_] = true;
        ownerList.push(address_);
        emit OwnerAdded(msg.sender, address_, block.timestamp);
    }

    /// @notice Remove existing owner, only master owner can remove
    /// @param address_ Address to remove
    function removeOwner(address address_) public onlyMasterOwner {
        require(ownerMap[address_], "Address is not an owner");
        require(address_ != masterOwner, "Master owner can't be removed");
        uint256 lengthBefore = ownerList.length;
        for (uint256 i = 0; i < ownerList.length; i++) {
            if (ownerList[i] == address_) {
                ownerMap[address_] = false;
                for (uint256 j = i; j < ownerList.length - 1; j++) {
                    ownerList[i] = ownerList[i + 1];
                }
                ownerList.pop();
                break;
            }
        }
        uint256 lengthAfter = ownerList.length;
        require( // Sanity check
            lengthAfter < lengthBefore,
            "Something went wrong removing owners"
        );
        emit OwnerRemoved(msg.sender, address_, block.timestamp);
    }

    /// @notice Let master owner renounce contract
    /// @param check Requires "give" as a parameter to prevent accidental renouncing
    function renounceOwnership(string memory check) external onlyMasterOwner {
        string memory checkAgainst = "confirm";
        require(
            keccak256(bytes(check)) == keccak256(bytes(checkAgainst)),
            "Can't renounce without 'confirm' as a parameter"
        );
        renounced = true;
        emit OwnershipRenounced(block.timestamp);
    }
}
