// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/JBXDelegateMetadataLib.sol";

contract JBXDelegateMetadataLib_Test is Test {
    ForTest_JBXDelegateMetadataLib parser;

    function setUp() external {
        parser = new ForTest_JBXDelegateMetadataLib();
    }

    function test_parse() external {
        bytes4 _id = bytes4(0x33333333);

        bytes memory _metadata = abi.encodePacked(
            // -- offset 0 --
            bytes32(uint256(type(uint256).max)),    // First 32B reserved
            
            // -- offset 1 --
            bytes4(0x11111111), // First delegate id
            uint8(2),       // First delegate offset == 2
            _id,                     // Second delegate id == _id
            uint8(3),       // Second delegate offset == 3
            bytes22(0),     // Rest of the word is 0-padded

            // -- offset 2 --
            bytes32(hex'deadbeefdeadbeef'),   // First delegate metadata

            // -- offset 3 --
            bytes32(uint256(type(uint256).max))   // Second delegate metadata
        );

        bytes memory _out = parser.getMetadata(_id, _metadata);
        emit log_bytes(_out);
    }

    function test_create() external {
        bytes4[] memory _ids = new bytes4[](3);
        bytes[] memory _metadatas = new bytes[](3);

        for(uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i));
            _metadatas[_i] = 'deadbeef';
        }

        bytes memory _out = parser.createMetadata(_ids, _metadatas);
        emit log_bytes(_out);
    }
}

/**
 * @dev Harness to deploy and test JBXDelegateMetadataLib
 */
contract ForTest_JBXDelegateMetadataLib {
    function getMetadata(bytes4 _delegateId, bytes calldata _metadata) external pure returns(bytes memory _targetMetadata) {
        return JBXDelegateMetadataLib.getMetadata(_delegateId, _metadata);
    }

event Test(uint);
    function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) external returns(bytes memory _metadata) {
        uint256 _numberOfIds = _ids.length;
        uint256 _nextOffsetCounter;

        _metadata = abi.encodePacked(bytes32(0)); // First word reserved for protocol
        _nextOffsetCounter++;

        // Create enough space for the ids and offsets
        uint256 _numberOfBytesForIds = 5 * _ids.length;
        // 0-pad the ids/offset
        _numberOfBytesForIds = _numberOfIds % 32 == 0 ? _numberOfIds : _numberOfIds += 32 - _numberOfIds % 32;

        assert(_numberOfBytesForIds % 32 == 0);

        _nextOffsetCounter += _numberOfBytesForIds / 32;

        for(uint256 _i; _i < _ids.length - 1; _i++) {
            emit Test(_i);
            _metadata = abi.encodePacked(_metadata, _ids[_i], _nextOffsetCounter);
            _nextOffsetCounter += _metadatas[_i].length / 32;
        }

        for(uint256 _i; _i < _ids.length - 1; _i++) {
            _metadata = abi.encodePacked(_metadata, _metadatas[_i]);
        }
    }  

}