// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library JBXDelegateMetadataLib {

    /** 
        -- offset 0 --
        bytes32 reserved for protocol

        -- offset 1 --
        bytes4 id
        bytes1 offset (in number of 32B words, counting from
        (...)
        last part == 0 padded
        
        -- offset 2 --
        bytes xxx - metadata
     */

    function getMetadata(bytes4 _id, bytes calldata _metadata) internal pure returns(bytes memory _targetMetadata) {
        // Either no metadata or empty one with only one selector (32+4+1)
        if(_metadata.length < 37) return '';

        // Parse the id's -> stop when next offset == 0 or current = first offset
        uint8 _firstOffset = uint8(_metadata[32+4]);

        for(uint256 _i = 32; _metadata[_i] != bytes1(0) && uint8(_metadata[_i]) != _firstOffset * 32; _i += 5) {
            // id found?
            if(bytes4(_metadata[_i:_i+4]) == _id) {
                // End of the calldata (either start of data's or next offset is 0)
                if(_i + 5 == _firstOffset || _metadata[_i + 9] == 0)
                    return _metadata[uint8(_metadata[_i + 4]) * 32 : _metadata.length];

                // If not, only return until next offset
                return _metadata[uint8(_metadata[_i + 4]) * 32 : uint8(_metadata[_i + 9]) * 32];
            }
        }
    }
        
    // Pack dem data (offchain helper)
    function createMetadata(bytes4[] calldata _ids, bytes[] calldata _metadatas) internal pure returns(bytes memory _metadata) {
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
            _metadata = abi.encodePacked(_metadata, _ids[_i], _nextOffsetCounter);
            _nextOffsetCounter += _metadatas[_i].length / 32;
        }

        for(uint256 _i; _i < _ids.length - 1; _i++) {
            _metadata = abi.encodePacked(_metadata, _metadatas[_i]);
        }
    }
}