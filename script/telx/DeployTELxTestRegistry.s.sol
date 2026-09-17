// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {StateView} from "@uniswap/v4-periphery/src/lens/StateView.sol";
import {PositionRegistry} from "../../contracts/telx/core/PositionRegistry.sol";
import {TELxSubscriber} from "../../contracts/telx/core/TELxSubscriber.sol";
import {IPositionRegistry} from "../../contracts/telx/interfaces/IPositionRegistry.sol";
import {TELxPoolScriptBase} from "./base/TELxPoolScriptBase.sol";

/**
 * @title DeployTELxTestRegistry
 * @notice Deploys a TEST PositionRegistry and TELxSubscriber from an EOA, wired together, for
 *         exercising the subscription flow against a live pool.
 * @dev    NOT the production deploy. `DeployTELxRegistry` goes through the governance Safe and
 *         CreateX CREATE3 so the contracts land at the published cross-chain addresses. This script
 *         uses plain CREATE from the signer, so the addresses depend only on the signer and its
 *         nonce and can never collide with the published ones. The signer holds every role and owns
 *         the subscriber; do not point Snapshot or any other integration at these contracts.
 *
 *         Usage:
 *
 *           forge script script/telx/DeployTELxTestRegistry.s.sol:DeployTELxTestRegistry \
 *             --rpc-url $ETHEREUM_RPC_URL --broadcast
 */
contract DeployTELxTestRegistry is TELxPoolScriptBase {
    /// @notice The production addresses published for the Safe-driven CREATE3 deploy.
    address internal constant PUBLISHED_REGISTRY = 0x00637FBbae593E920B1d08300EC1f05d6D61Aa61;
    address internal constant PUBLISHED_SUBSCRIBER = 0xD9e2c4A560ba8FD0f28A5Bf25B3940576cc53fEC;

    /// @notice Production entrypoint. Resolves the signer from env and delegates.
    function run() external returns (PositionRegistry registry, TELxSubscriber subscriber) {
        return runWithSigner(_resolveSigner());
    }

    /**
     * @notice Explicit-signer entrypoint, called directly by fork tests.
     * @param signer Address to broadcast from; becomes admin, support and subscriber owner.
     */
    function runWithSigner(address signer) public returns (PositionRegistry registry, TELxSubscriber subscriber) {
        ChainConfig memory config = _chainConfig();

        vm.startBroadcast(signer);
        registry = new PositionRegistry(
            IPositionManager(config.positionManager), StateView(config.stateView), signer
        );
        subscriber = new TELxSubscriber(IPositionRegistry(address(registry)), config.positionManager, signer);
        registry.grantRole(registry.SUBSCRIBER_ROLE(), address(subscriber));
        registry.grantRole(registry.SUPPORT_ROLE(), signer);
        vm.stopBroadcast();

        require(address(registry) != PUBLISHED_REGISTRY, "Landed on the published registry address");
        require(address(subscriber) != PUBLISHED_SUBSCRIBER, "Landed on the published subscriber address");
        require(registry.hasRole(registry.SUBSCRIBER_ROLE(), address(subscriber)), "Post-check: subscriber unwired");
        require(address(subscriber.registry()) == address(registry), "Post-check: subscriber registry");

        console2.log("=== TEST TELx registry on", config.name, "===");
        console2.log("  PositionRegistry:", address(registry));
        console2.log("  TELxSubscriber:  ", address(subscriber));
        console2.log("  admin/owner:     ", signer);
    }
}
