// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/resources/link-token-contracts/
 */

/**
 * @title GettingStartedFunctionsConsumer
 * @notice This is an example contract to show how to make HTTP requests using Chainlink
 * @dev This contract uses hardcoded values and should not be used in production.
 */
contract NFTPricingOracle is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Mapping from RequestId and collecttion address, maintaining the
    mapping(bytes32 => address) private _requestToCollectionAddr;

    // NFT meta info given collection address and token ID, usually update once
    mapping(address => mapping(uint256 => TokenMetaInfo))
        private _collectionMetaInfo;

    // NFT trait weights mapping given collection address and trait ID, update periodically
    mapping(address => mapping(uint256 => uint256)) private _traitWeights;

    // Scale to scale the number
    uint256 public constant scale = 10000;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Struct to store token straits
    struct TokenMetaInfo {
        uint256[] traitsIDs;
        uint256[] traitsMultiple;
    }

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        uint256 value,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Sepolia
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    // Fetch Value from the Gopricing API.
    string source = "const contractAddress = '0x' + args[0];const apiResponse = await Functions.makeHttpRequest({url: `https://pricing-online-service-prod.nftgo.io/service/v1/oracle/v2/collection-weights?contract_address=${contractAddress}`,headers: {'X-API-KEY': 'c5d40aad-7a3b-4c7f-81c4-bc3a914d5045','accept': 'application/json'}});if (apiResponse.error) {console.error('Request failed:', apiResponse.error);throw Error('Request failed');}const dataArray = apiResponse['data'];const limitedArray = dataArray.slice(0, 64).concat(Array(Math.max(64 - dataArray.length, 0)).fill(0));const int32Array = new Int32Array(limitedArray);const buffer = Buffer.alloc(int32Array.length * 4);int32Array.forEach((value, index) => {buffer.writeInt32LE(value, index * 4);});return buffer;";

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // State variable to store the returned value information
    uint32[] public value;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    /**
     * @notice Sends an HTTP request for value information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external returns (bytes32 requestId) {
        require(args.length > 0, "Insufficient arguments provided");

        // Validate args[0] as an address
        // address collectionAddr;
        // bytes memory addrBytes = bytes(args[0]);
        // if (addrBytes.length == 40) {
        //     collectionAddr = address(bytes20(addrBytes));
        // } else {
        //     revert("Invalid address format in args[0]");
        // }

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
        // _requestToCollectionAddr[s_lastRequestId] = collectionAddr;

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
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }

        // Check if the collection address for the requestId exists
        // address currentCollection = _requestToCollectionAddr[requestId];
        // require(
        //     currentCollection != address(0),
        //     "Collection address does not exist"
        // );

        // Decode the response from bytes to uin32[]
        // uint32[] memory decodedResponse;
        // if (response.length > 0) {
        //     decodedResponse = abi.decode(response, (uint32[]));
        //     updateTraitWeights(currentCollection, decodedResponse);
        // } else {
        //     revert("Empty response cannot be decoded");
        // }

        // Update the contract's state variables with the decoded response and any errors
        s_lastResponse = response;
        value = abi.decode(response, (uint32[]));
        s_lastError = err;

        // Emit an event to log the response
        // emit Response(requestId, value, s_lastResponse, s_lastError);

        // Delete the key-value pair from the mapping
        // delete _requestToCollectionAddr[requestId];
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
    ) public view returns (uint256, uint256) {
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
     * @dev     Yusen
     * @param   collection  Collection Address
     * @param   traitWeights  The array of trait weights from chainlink DON and traitWeights[0] is the model intercept
     */
    function updateTraitWeights(
        address collection,
        uint32[] memory traitWeights
    ) public {
        // update trait weights to state mapping _traitWeights
        for (uint256 i = 0; i < traitWeights.length; i++) {
            _traitWeights[collection][i] = uint256(traitWeights[i]);
        }
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
    function getCollectionMetaInfo(
        address collection,
        uint256 tokenid
    ) public view returns (uint256[] memory, uint256[] memory) {
        // Return the traitIDs and TraitMutiple given collection address and tokenid
        return (
            _collectionMetaInfo[collection][tokenid].traitsIDs,
            _collectionMetaInfo[collection][tokenid].traitsMultiple
        );
    }
}
