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

    function hasPendingTransferRequest() public constant returns (bool){
        return transitionState;
    }

    function changeOwner(address _newOwner) public onlyOwner returns (bool) {
        require(_newOwner != address(0));
        newOwner = _newOwner;
        transitionState = true;
        OwnershipTransferInitiated(owner, _newOwner);
        return true;
    }

    function acceptOwnership() public returns (bool){
        require(newOwner == msg.sender);
        owner = newOwner;
        transitionState = false;
        OwnershipTransferAccepted(owner);
        return true;
    }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * @notice This is a softer (in terms of throws) variant of SafeMath:
 *         https://github.com/OpenZeppelin/openzeppelin-solidity/pull/1121
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 _a, uint256 _b) internal constant returns (uint256) {
        uint256 c;
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (_a == 0) {
            return 0;
        }
        c = _a * _b;
        require(c / _a == _b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 _a, uint256 _b) internal constant returns (uint256) {
        // Solidity automatically throws when dividing by 0
        // therefore require beforehand avoid throw
        require(_b > 0);
        // uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
        return _a / _b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 _a, uint256 _b) internal constant returns (uint256) {
        require(_b <= _a);
        return _a - _b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 _a, uint256 _b) internal constant returns (uint256 c) {
        c = _a + _b;
        require(c >= _a);
        return c;
    }

    function max(uint256 a, uint256 b) internal constant returns (uint256) {
        return a > b ? a : b;
    }
}

/// @title Bridge Operator Standard implementation for AIP #005 to achieve the cross chain
/// functionality for the tokens or assets on Ethereum network
contract BridgeOperatorBase is Owned {
    using SafeMath for uint256;

    uint256 constant MAX_SIGNATORIES = 32;
    uint256 internal signatoriesCount;
    uint256 internal approval;
    mapping(address => bool) internal signatories;
    mapping(bytes32 => bytes32) internal bundleTxMap;

    // this registry holds information about valid signatories
    SignatoryRegistry signatoryRegistry =
        SignatoryRegistry(signatory-registry-contract-address-here);

    // this address points to ATS implementation
    ATSTokenBase atsTokenBase = 
        ATSTokenBase(ATS-token-contract-address-here);

    /// @notice informs that the given signatory is available for transfer verification
    event AddedSignatory(address _signatory);

    /// @notice informs that the given signatory can no more participate in transfer verification
    event RemovedSignatory(address _signatory);

    /// @notice bridge operator releases the asset on the destination chain at the end of bundle verification
    event Distributed(
        bytes32 indexed sourceTransactionHash,
        address indexed recipient,
        uint256 indexed amount,
        bytes32 initTransferHash
    );

    /// @notice the bundle has been processed without any errors
    event ProcessedBundle(
        bytes32 indexed sourceBlockHash,
        bytes32 indexed bundleHash
    );

    /// @notice inform that the bundle has already been processed
    event SuccessfulTransactionHash(
        bytes32 indexed destinationTransactionHash
    );

    function BridgeOperatorBase() public {
        signatoriesCount = 0;
    }

    /// @notice initialize the group of signatories for the bridge operator
    /// @dev signatories cannot be reinitialized if already initialized
    /// @param _signatories list of signatory addresses
    function initializeSignatories(address[] _signatories) public onlyOwner {
        require(_signatories.length != 0);
        require(_signatories.length < MAX_SIGNATORIES);
        require(signatoriesCount == 0);
        require(signatoriesCount < MAX_SIGNATORIES);

        for (uint256 i=0; i < _signatories.length; i++) {
            if (signatoryRegistry.isValid(address(_signatories[i]))) {
                signatories[_signatories[i]] = true;
                signatoriesCount++;
            }
        }

        require(signatoriesCount > 0);
        
        uint256 count = signatoriesCount.mul(2).div(3);
        approval = count.max(1);
    }

    /// @notice bridge operator onboards a signatory after initializing the bridge
    /// @param _signatory signatory address
    function addSignatory(address _signatory) public onlyOwner {
        require(_signatory != address(0));
        require(signatoriesCount < MAX_SIGNATORIES);
        require(!signatories[_signatory]);
        require(signatoryRegistry.isValid(address(_signatory)));

        signatories[_signatory] = true;
        signatoriesCount += 1;
        uint256 count = signatoriesCount.mul(2).div(3);
        approval = count.max(1);

        AddedSignatory(_signatory);
    }

    /// @notice bridge operator removes an existing signatory if it does not want to
    /// participate in the transfer process or cannot be trusted further
    /// @param _signatory signatory address
    function removeSignatory(address _signatory) public onlyOwner {
        require(_signatory != address(0));
        require(signatories[_signatory]);

        signatories[_signatory] = false;
        signatoriesCount -= 1;
        uint256 count = signatoriesCount.mul(2).div(3);
        approval = count.max(1);

        RemovedSignatory(_signatory);
    }

    /// @notice checks if given signatory is selected for this bridge's transfer process
    /// @param _signatory signatory address
    /// @return true or false
    function isValidSignatory(address _signatory) public returns (bool) {
        return signatories[_signatory];
    }

    /// @notice returns number of selected signatories participating in the transfer process
    /// @return number
    function validSignatoriesCount() constant returns (uint256) {
        return signatoriesCount;
    }

    /// @notice returns the minimum number of selected signatories required to thaw tokens on 
    /// the destination network.
    /// @return number
    function minimumSignatoriesApproval() constant returns (uint256) {
        return approval;
    }

    /// @notice Bridge operator verifies that the signatories threshold is met. Thaw function is
    /// called in the ATS to release the assets at the end of current bundle verification and
    /// emits Distributed event.
    /// @dev If the bundle is successfully verified, it emits ProcessedBundle event. If a
    /// bundle has already been previously verified and exists then it emits
    /// SuccessfulTransactionHash event with its correct parameter.
    /// @param _sourceBlockHash The block hash from the source chain having transfer transactions
    /// @param _sourceTransactionHashes The transfer transaction hashes in sourceBlockHash from 
    /// the source chain
    /// @param _recipients The destination chain account addresses participating in transfer process
    /// @param _amounts The respective amounts to be thawed by bridge operator
    /// @param _V The 'v' component of a signature of Secp256k1
    /// @param _R The 'r' component of a signature of Secp256k1
    /// @param _S The 's' component of a signature of Secp256k1
    /// @param _initTransferHashes keccak256 hashes of respective transfer recipients, amounts, UUIDs
    function processBundle(
        bytes32 _sourceBlockHash,
        bytes32[] _sourceTransactionHashes,
        address[] _recipients,
        uint256[] _amounts,
        uint8[] _V,
        bytes32[] _R,
        bytes32[] _S,
        bytes32[] _initTransferHashes
    ) 
        public 
        onlyOwner
    {
        require(_sourceBlockHash != 0);
        require(_sourceTransactionHashes.length == _recipients.length);
        require(_recipients.length == _amounts.length);
        require(approval > 0);
        require(_V.length >= approval);

        bytes32 transferBundleHash = sha3(
            _sourceBlockHash,
            _sourceTransactionHashes,
            _recipients,
            _amounts
        );

        if (bundleTxMap[transferBundleHash] != 0) {
            SuccessfulTransactionHash(getBundle(transferBundleHash));
            return;
        }
        
        require(bundleTxMap[transferBundleHash] == 0);

        //verify signatures
        hasEnoughSignatures(transferBundleHash, _V, _R, _S);

        uint256 i;
        for (i = 0; i < _sourceTransactionHashes.length; ++i) {
            atsTokenBase.thaw(
                _recipients[i],
                _amounts[i],
                this,
                _sourceTransactionHashes[i],
                _initTransferHashes[i]
            );
            Distributed(
                _sourceTransactionHashes[i], 
                _recipients[i], 
                _amounts[i], 
                _initTransferHashes[i]
            );
        }

        // Ethereum does not have support for transaction hash, hence setting it
        // to fixed value 1 temporarily
        bundleTxMap[transferBundleHash] = 0x1;
        ProcessedBundle(_sourceBlockHash, transferBundleHash);
    }

    /// @notice returns 1 if bundle is already processed, however this method is ignored for now
    /// @param _bundleHash hash of transfer bundle
    /// @return returns 1
    function getBundle(bytes32 _bundleHash) constant returns (bytes32) {
        return bundleTxMap[_bundleHash];
    }

    /// @notice bridge operator sets the mapping to 1 if bundle is already processed, however, 
    /// this method is ignored for now
    /// @param _bundleHash hash of transfer bundle
    /// @param _transactionHash transaction hash from the processBundle operation
    function setBundle(bytes32 _bundleHash, bytes32 _transactionHash) public onlyOwner {
        if (bundleTxMap[_bundleHash] == 0x1)
            bundleTxMap[_bundleHash] = _transactionHash;
    }

    /// @param _transferBundleHash The bundle hash of the transfer to be validated
    /// @param _V The 'v' component of a signature of Secp256k1
    /// @param _R The 'r' component of a signature of Secp256k1
    /// @param _S The 's' component of a signature of Secp256k1
    function hasEnoughSignatures(
        bytes32 _transferBundleHash, 
        uint8[] _V, 
        bytes32[] _R, 
        bytes32[] _S
    )  
        internal  
    {
        uint256 i;
        uint256 signed = 0;
        for (i = 0; i < _V.length; ++i) {
            address signatory = ecrecover(_transferBundleHash, _V[i], _R[i], _S[i]);

            require(isValidSignatory(signatory));
            require(signatoryRegistry.isValid(signatory));

            if (signatories[signatory]) {
                signed += 1;
            }
        }
        require(signed >= approval);
    }
}

/// @title reference to the functions in the ERC20 controller (ATS) implementation
contract ATSTokenBase {
    function thaw(
        address _recipient, 
        uint256 _amount, 
        address _bridgeAddress,
        bytes32 _sourceTransactionHash, 
        bytes32 _initTransferHash
    ) 
    public;
}

/// @title reference to the functions in the Signatory Registry implementation
contract SignatoryRegistry {
    function isValid(address _signatory) public returns (bool);
}