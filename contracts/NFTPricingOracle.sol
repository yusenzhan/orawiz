// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "../interface/NFTPricingInterface.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/resources/link-token-contracts/
 */

/**
 * @title GettingStartedFunctionsConsumer
 * @notice This is an example contract to show how to make HTTP requests using Chainlink
 * @dev This contract uses hardcoded values and should not be used in production.
 */
contract NFTPricingOracle is FunctionsClient, ConfirmedOwner, NFTPricingInterface{
    using FunctionsRequest for FunctionsRequest.Request;

    // State variables to store the last request ID, response, error and array
    address[] public upkeepContracts;
    bytes public request;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint256[] public s_lastDecodedArray;

    // NFT meta info given collection address and token ID, usually update once
    mapping(address => mapping(uint256 => TokenMetaInfo))
        private _collectionMetaInfo;

    // Mapping from RequestId and collecttion address, maintaining the
    mapping(bytes32 => address) private _requestToCollectionAddr;

    // NFT trait weights mapping given collection address and trait ID, update periodically
    // mapping(address => mapping(uint256 => uint256)) private _traitWeights;
    mapping(address => uint32[]) private _traitWeights;

    // The mapping stored the number of traits given the collection address
    mapping(address => uint256) private _addressToTraitNum;

    // Scale to scale the number
    uint256 public constant scale = 10000;

    // Custom error type
    error InvalidInputLength(uint256 length);

    error NotAllowedCaller(
        address caller,
        address owner,
        address automationRegistry
    );

    // Struct to store token straits
    struct TokenMetaInfo {
        uint256[] traitsIDs;
        uint256[] traitsMultiple;
    }

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        address currentCollection,
        uint256 arrayLength,
        bytes err
    );

    // Router address - Hardcoded for Polygon-mumbai
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C;

    // JavaScript source code
    // Fetch Value from the Gopricing API.
    string public source =
        "const ethers = await import('npm:ethers@6.10.0');"
        "const contractAddress = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: `https://pricing-online-service-prod.nftgo.io/service/v1/oracle/v2/collection-weights?contract_address=${contractAddress}`,"
        "headers: { 'X-API-KEY': 'c5d40aad-7a3b-4c7f-81c4-bc3a914d5045', accept: 'application/json' },"
        "});"
        "if (apiResponse.error) {"
        "console.error('Request failed:', apiResponse.error);"
        "throw Error('Request failed');"
        "}"
        "const dataArray = apiResponse['data'];"
        "let concatenatedHexString = '0x';"
        "dataArray.forEach((element) => {"
        "const encodedElement = ethers.solidityPacked(['uint32'], [element]);"
        "concatenatedHexString += encodedElement.slice(2);"
        "});"
        "return ethers.getBytes(concatenatedHexString);";

    //Callback gas limit
    uint32 gasLimit = 1499999;

    // donID - Hardcoded for Polygon-mumbai
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    /**
     * @notice Reverts if called by anyone other than the contract owner or automation registry.
     */
    modifier onlyAllowed() {
        bool isAllowed = msg.sender == owner();
        if (!isAllowed) {
            for (uint256 i = 0; i < upkeepContracts.length; i++) {
                if (msg.sender == upkeepContracts[i]) {
                    isAllowed = true;
                    break;
                }
            }
        }

        require(isAllowed, "NotAllowedCaller");
        _;
    }

    
    /**
     * @notice  Add the UpKeep Contract to the oracel contract
     * @param   _upkeepContract  new UpKeep Contract address from Chainlink Automation
     */
    function addUpkeepContract(address _upkeepContract) external onlyOwner {
        upkeepContracts.push(_upkeepContract);
    }

    /**
     * @notice  Remove UpKeep Contract from the oracle contract
     * @param   _upkeepContract  The contract is supposed to be delete
     */
    function removeUpkeepContract(address _upkeepContract) external onlyOwner {
        uint256 length = upkeepContracts.length;
        for (uint256 i = 0; i < length; i++) {
            if (upkeepContracts[i] == _upkeepContract) {
                // Move the last element into the place to delete
                upkeepContracts[i] = upkeepContracts[length - 1];
                // Remove the last element
                upkeepContracts.pop();
                break; // Exit the loop once the address is found and removed
            }
        }
    }

    /// @notice Update the request settings
    /// @dev Only callable by the owner of the contract
    /// @param _request The new encoded CBOR request to be set. The request is encoded offchain
    /// @param _subscriptionId The new subscription ID to be set
    /// @param _gasLimit The new gas limit to be set
    /// @param _donID The new job ID to be set
    // function updateRequest(
    //     string memory _source,
    //     uint64 _subscriptionId,
    //     uint32 _gasLimit,
    //     bytes32 _donID
    // ) external onlyOwner {

    //     request = _request;
    //     subscriptionId = _subscriptionId;
    //     gasLimit = _gasLimit;
    //     donID = _donID;
    // }

    /**
     * @notice Sends an HTTP request for value information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequestCBOR(uint64 subscriptionId, string[] calldata args)
        external
        onlyAllowed
        returns (bytes32 requestId)
    {
        require(args.length > 0, "Insufficient arguments provided");

        address collection_address = hexStringToAddress(args[0]);

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        // store latest request id to mapping and collection address
        _requestToCollectionAddr[s_lastRequestId] = collection_address;

        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        s_lastError = err;

        // Check if the collection address for the requestId exists
        address currentCollection = _requestToCollectionAddr[requestId];
        require(
            currentCollection != address(0),
            "Collection address does not exist"
        );

        if (response.length > 0) {
            if (response.length % 4 != 0) {
                revert InvalidInputLength(response.length);
            }

            uint256 numberOfElements = response.length / 4;
            uint32[] memory decodedArray = new uint32[](numberOfElements);

            assembly {
                // Pointer to the start of the response data
                let dataStart := add(response, 0x20)
                // Pointer to the start of the decodedArray data
                let dataEnd := add(decodedArray, 0x20)

                for {
                    let i := 0
                } lt(i, numberOfElements) {
                    i := add(i, 1)
                } {
                    let element := mload(add(dataStart, mul(i, 4)))
                    // Store the 32-bit element, shifting right to correct for byte ordering
                    mstore(add(dataEnd, mul(i, 0x20)), shr(224, element))
                }
            }

            updateTraitWeights(currentCollection, decodedArray);

            // s_lastDecodedArray = decodedArray;
            emit Response(
                requestId,
                currentCollection,
                decodedArray.length,
                err
            );
        }
    }

    /**
     * @notice  The this the main function to get the estimate price from the Oracle Contract
     * @param   collection Collection Address
     * @param   tokenid  Token ID
     * @param   floorPrice  Please provide floor price when you call this function
     * @return  uint256  Estimate price in unit256 type
     * @return  uint256  State variable scale for further usage
     */
    function getEtimatePrice(
        address collection,
        uint256 tokenid,
        uint256 floorPrice
    ) external view override returns (uint256, uint256) {
        // Declare the trait ID and Mutiple arrays
        uint256[] memory traitIDs;
        uint256[] memory traitsMutiple;

        // get metainfo
        (traitIDs, traitsMutiple) = getCollectionMetaInfo(collection, tokenid);

        // Check if the length of traitIDs and traitsMutiple are equal
        require(
            traitIDs.length == traitsMutiple.length,
            "Trait IDs and Multiples length mismatch"
        );

        // Initialize accumWeights
        uint256 accumWeights = _traitWeights[collection][0]; //1+intercept

        // Iterate over trait IDs
        for (uint256 i = 0; i < traitIDs.length; i++) {
            uint256 tempWeight = uint256(
                _traitWeights[collection][traitIDs[i]]
            );

            // Skip the calculation if tempWeight is zero
            if (tempWeight == 0) {
                continue;
            }

            // Calculate and accumulate weights
            accumWeights += (traitsMutiple[i] * tempWeight) / scale;
        }

        uint256 estimatePrice = (accumWeights * floorPrice) / scale;

        return (estimatePrice, scale); // returns the estimated price and scale
    }

    /**
     * @notice  Call this function to update trait weight periodically
     * @param   collection  Collection Address
     * @param   traitWeights  The array of trait weights from chainlink DON and traitWeights[0] is the model intercept
     */
    function updateTraitWeights(
        address collection,
        uint32[] memory traitWeights
    ) public {
        // Set the number of traits
        _addressToTraitNum[collection] = traitWeights.length;

        // update trait weights to state mapping _traitWeights
        _traitWeights[collection] = traitWeights;
    }

    /**
     * @notice Call this function to retrieve trait weights for a given collection
     * @param collection Collection Address
     * @return traitWeights The array of trait weights for the collection
     */
    function getTraitWeights(address collection)
        public
        view
        returns (uint32[] memory)
    {
        return _traitWeights[collection];
    }

    /**
     * @notice Call this function to retrieve the number of traits for a given collection address
     * @param collection The collection address
     * @return The number of traits associated with the collection address
     */
    function getNumberOfTraits(address collection)
        public
        view
        returns (uint256)
    {
        return _addressToTraitNum[collection];
    }

    /**
     * @notice  This function is used to upload collection meta info to Oracle contract by collection, usually call once by off-chain service
     * @param   collection  Collection Address
     * @param   tokenids  Array of token IDs
     * @param   traitsIDsBatch  The 2-D arrays of trait IDs
     * @param   traitsMultipleBatch  the 2-D arrays of  multiple of traits
     */
    function setCollectionMetaInfoBatch(
        address collection,
        uint256[] memory tokenids,
        uint256[][] memory traitsIDsBatch,
        uint256[][] memory traitsMultipleBatch
    ) public onlyOwner {
        require(
            tokenids.length == traitsIDsBatch.length &&
                tokenids.length == traitsMultipleBatch.length,
            "Array lengths must match"
        );

        for (uint256 i = 0; i < tokenids.length; i++) {
            require(
                traitsIDsBatch[i].length == traitsMultipleBatch[i].length,
                "Traits IDs and Multiples length mismatch"
            );
            _collectionMetaInfo[collection][tokenids[i]] = TokenMetaInfo(
                traitsIDsBatch[i],
                traitsMultipleBatch[i]
            );
        }
    }

    /**
     * @notice  This function is used to upload collection meta info to Oracle contract by token, usually call once by off-chain service
     * @param   collection  Collection Address
     * @param   tokenid  Token ID
     * @param   traitsIDs  The array of trait IDs for the token
     * @param   traitsMultiple  The array of multiple of traits
     */
    function setCollectionMetaInfo(
        address collection,
        uint256 tokenid,
        uint256[] memory traitsIDs,
        uint256[] memory traitsMultiple
    ) public onlyOwner {
        // Set the value for the user's specific ID.
        _collectionMetaInfo[collection][tokenid] = TokenMetaInfo(
            traitsIDs,
            traitsMultiple
        );
    }

    /**
     * @notice  This function is the getter function for collection meta info
     * @param   collection  Collection Address
     * @param   tokenid  Token ID
     * @return  uint256[]  The array of trait IDs for the token
     * @return  uint256[]  The array of multiple of traits
     */
    function getCollectionMetaInfo(address collection, uint256 tokenid)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        // Return the traitIDs and TraitMutiple given collection address and tokenid
        return (
            _collectionMetaInfo[collection][tokenid].traitsIDs,
            _collectionMetaInfo[collection][tokenid].traitsMultiple
        );
    }

    /**
     * @notice  Convert a hex string to an address using optimized assembly
     * @param   hexString  The input Hex String
     * @return  addr  the output address from hexString
     */
    function hexStringToAddress(string memory hexString)
        public
        pure
        returns (address addr)
    {
        require(bytes(hexString).length == 42, "Invalid input length");
        uint256 result;
        uint256 temp;

        assembly {
            // Skip the "0x" prefix by starting the loop at the third byte
            for {
                let i := 2
            } lt(i, 42) {
                i := add(i, 1)
            } {
                // Load the byte at the current position
                temp := byte(0, mload(add(add(hexString, 0x20), i)))
                // Convert ASCII to hex value
                switch lt(temp, 58) // Check if the byte is '0'-'9'
                case 1 {
                    temp := sub(temp, 48)
                } // '0'-'9'
                case 0 {
                    switch lt(temp, 97) // Check if the byte is 'A'-'F'
                    case 1 {
                        temp := sub(temp, 55)
                    } // 'A'-'F'
                    case 0 {
                        temp := sub(temp, 87)
                    } // 'a'-'f'
                }
                // Shift result left by 4 (making room for the new digit) and add the new value
                result := or(shl(4, result), temp)
            }
            // Cast the result to an address
            addr := result
        }
    }
}
