// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserInfo {
    // State variables
    string public name;
    string public age;
    string public userAddress;

    // Function to set user information
    function setUserInfo(string memory _name, uint256 _age, address _userAddress) public {
        name = _name;
        age = _age;
        userAddress = _userAddress;
    }

    // Function to get user information
    function getUserInfo() public view returns (string memory, uint256, address) {
        return (name, age, userAddress);
    }

    // Function to increment age by 1
    function incrementAge() public {
        age += 1;
    }

    // Function to retrieve the length of the name string
    function getNameLength() public view returns (uint256) {
        return bytes(name).lenth;
    }
}