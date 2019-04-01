/**

MIT License

Copyright (c) 2019 Mavennet Systems Inc. https://mavennet.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

 */

pragma solidity 0.4.15;

contract Owned {
    address public owner;
    address newOwner;
    bool private transitionState;

    event OwnershipTransferInitiated(address indexed _previousOwner, address indexed _newOwner);
    event OwnershipTransferAccepted(address indexed _newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyNotOwner() {
        require(msg.sender != owner);
        _;
    }

    function Owned() {
        owner = msg.sender;
        newOwner = msg.sender;
        transitionState = false;
    }

    function owner() public constant returns (address) {
        return owner;
    }

    function isOwner() public constant returns (bool) {
        return msg.sender == owner;
    }

    function hasPendingTransferRequest() public constant returns (bool) {
        return transitionState;
    }

    function changeOwner(address _newOwner) public onlyOwner returns (bool) {
        require(_newOwner != address(0));
        newOwner = _newOwner;
        transitionState = true;
        OwnershipTransferInitiated(owner, _newOwner);
        return true;
    }

    function acceptOwnership() public returns (bool) {
        require(newOwner == msg.sender);
        owner = newOwner;
        transitionState = false;
        OwnershipTransferAccepted(owner);
        return true;
    }

}

/// @title A Bridge Registry contract used to maintain the list of valid bridge operators for
/// token transfer process.
contract BridgeRegistry is Owned {
    mapping(address => bool) internal bridgeOperators;

    event AddedBridgeOperator(address indexed bridgeOperator);
    event RemovedBridgeOperator(address indexed bridgeOperator);

    /// @notice adds a bridge operator to the registry
    /// @param bridgeOperator address
    function add(address bridgeOperator) public onlyOwner {
        require(bridgeOperator != address(0));

        bridgeOperators[bridgeOperator] = true;

        AddedBridgeOperator(bridgeOperator);
    }

    /// @notice removes a bridge operator to the registry
    /// @param bridgeOperator address
    function remove(address bridgeOperator) public onlyOwner {
        require(bridgeOperator != address(0));

        bridgeOperators[bridgeOperator] = false;

        RemovedBridgeOperator(bridgeOperator);
    }

    /// @notice checks if given bridge operator exists in the registry
    /// @param bridgeOperator address
    /// @return true or false
    function isValid(address bridgeOperator) constant public returns (bool) {
        return bridgeOperators[bridgeOperator];
    }
}