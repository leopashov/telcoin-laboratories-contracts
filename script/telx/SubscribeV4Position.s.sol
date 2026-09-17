// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {TELxSubscriber} from "../../contracts/telx/core/TELxSubscriber.sol";
import {IPositionRegistry} from "../../contracts/telx/interfaces/IPositionRegistry.sol";
import {TELxPoolScriptBase} from "./base/TELxPoolScriptBase.sol";

/**
 * @title SubscribeV4Position
 * @notice Subscribes a Uniswap v4 position to a TELxSubscriber, which records it in that
 *         subscriber's PositionRegistry.
 * @dev    The same call an LP makes from the TELx UI. The signer must own or be approved for the
 *         position. Checks eligibility first so an out-of-range or below-threshold position fails
 *         with a readable reason instead of a revert bubbled up through the PositionManager.
 *
 *         Usage:
 *
 *           forge script script/telx/SubscribeV4Position.s.sol:SubscribeV4Position \
 *             --rpc-url $ETHEREUM_RPC_URL --broadcast \
 *             --sig "run(uint256,address)" <tokenId> <subscriber>
 */
contract SubscribeV4Position is TELxPoolScriptBase {
    /// @notice Production entrypoint. Resolves the signer from env and delegates.
    function run(uint256 tokenId, address subscriber) external {
        runWithSigner(tokenId, subscriber, _resolveSigner());
    }

    /**
     * @notice Explicit-signer entrypoint, called directly by fork tests.
     * @param tokenId Position NFT id.
     * @param subscriber TELxSubscriber to subscribe the position to.
     * @param signer Owner of, or approved operator for, the position.
     */
    function runWithSigner(uint256 tokenId, address subscriber, address signer) public {
        ChainConfig memory config = _chainConfig();
        IPositionRegistry registry = TELxSubscriber(subscriber).registry();

        console2.log("Subscribing tokenId", tokenId);
        console2.log("  subscriber:", subscriber);
        console2.log("  registry:  ", address(registry));

        require(!registry.isTokenSubscribed(tokenId), "Already subscribed");
        require(!registry.belowSubscriptionThreshold(tokenId), "Position below the liquidity threshold");
        require(registry.subscriptionEligible(tokenId), "Position not eligible (out of range?)");

        vm.startBroadcast(signer);
        IPositionManager(config.positionManager).subscribe(tokenId, subscriber, "");
        vm.stopBroadcast();

        require(registry.isTokenSubscribed(tokenId), "Post-check: not recorded as subscribed");
        console2.log("Subscribed.");
    }
}
