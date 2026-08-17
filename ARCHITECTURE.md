# Architecture

## Runtime layout

The repository mirrors Roblox DataModel services on disk. `.vscode/generate-sourcemap.ps1` converts those directories into `sourcemap.json` for Luau Language Server resolution. Regenerate the sourcemap after adding, removing, or renaming source files; do not edit the generated JSON by hand.

- `StarterPlayer/StarterPlayerScripts/Client.local.luau` is the client bootstrap. It clones the server-staged interfaces into `PlayerGui`, requires client modules in `Core`, `Controllers`, then `UI` order, and invokes their `init`, `start`, and Studio-only `test` hooks.
- `ServerScriptService/Server.server.luau` is the server bootstrap. It validates and stages the `StarterGui.GameGUIs` package interfaces in `ReplicatedStorage`, requires server modules in `Core` then `Services` order, and invokes the same lifecycle hooks.
- `ReplicatedStorage/Client` contains client-only state, presentation, input, UI, and gameplay controllers.
- `ServerStorage/Server/Core` owns authoritative player data and foundational game systems such as characters, items, equipment, economy, products, collision, bans, rewards, and shutdown saves.
- `ServerStorage/Server/Services` owns server gameplay features that build on the core systems. Gun validation, shot replication, and global instance IDs live here.
- `ReplicatedStorage/Shared` contains code and data safe to require from either runtime: types, constants, weapon definitions, networking contracts, utility modules, and reusable classes.

## Ownership boundaries

- The server is authoritative for persistent state, inventory/equipment changes, damage, ammunition validation, and anti-exploit decisions. Client controllers may predict or present gameplay but must not become the source of truth.
- Shared modules must not depend on client-only or server-only modules. Runtime-specific adapters belong under `ReplicatedStorage/Client` or `ServerStorage/Server`.
- `Core` modules provide foundational state and lifecycle behavior. Feature-specific orchestration belongs in `Controllers` on the client and `Services` on the server.
- Gun responsibilities are split deliberately: `GunController` handles the local weapon lifecycle and presentation, `GunReplicationController` renders other players' weapons, and `BulletTrackingController` simulates local tracer visuals. `GunService` validates gun requests, while `BulletTrackingService` batches server-authorized shot replication.
- The Studio-only `HUD.MouseUnlock` modal is hold-to-use with Left Alt and must initialize hidden; while visible, it intentionally consumes mouse firing and camera input.
- Character equipment restoration must wait until `ItemService` has reconciled the player's inventory and default equipped items. Spawn callbacks must also verify that they still belong to the player's current character before cloning tools.
- Global instance references cross the network through `GlobalInstanceService` and `GlobalInstanceController`; consumers should use that mapping instead of inventing parallel instance-ID registries.

## Creature, loot, and selling loop

- `CreatureService` owns per-player creature records, health, lifetime, mutation rolls, hit validation, and loot rewards. Creatures do not exist as server NPC instances.
- `CreatureController` renders only the local player's targets from the shared snapshots. `CreatureUtil` evaluates deterministic movement from server time, so the server can validate hits without replicating moving target instances.
- `CreatureProtocol` is the binary contract for creature snapshots and lifecycle updates. Creature damage extends the existing gun damage action with the append-only `Creature` owner type.
- A creature hit is accepted only when it consumes a recent server-approved pellet and passes direction, travel-time, range, expected-position, expiry, and world-obstruction checks.
- `LootConstants` owns rarity order, drop weights, luck scaling, display metadata, and sell values. Loot entries are registered as non-purchasable consumables in `ItemConstants`, so `ItemService` remains the single persistent stack inventory.
- `SellService` owns sell valuation and inventory consumption. Sell requests require proximity to `Workspace.World.SellStand.Interaction`; clients never submit prices or quantities.
- All player-facing `ScreenGui` assets, including `SellUI` and `LootHUD`, are authored inside the `StarterGui.GameGUIs` package. Their screen modules bind behavior after the bootstrap stages them directly under `PlayerGui` and must not construct replacement UI trees at runtime.
- The equipped gun is automatically activated by `EquipmentToolService`, and `GunController` disables Roblox's default Backpack UI. Future Guns stand switching must continue through the equipment slot rather than exposing weapon hotbar selection.
- `ProfileTemplate.Progression` is the persistent extension point for the current world and Luck, Value Multiplier, Fire Rate, Damage, and Magazine Size upgrade levels.

The current vertical slice covers shooting creatures, receiving stackable loot, and selling all loot for Cash. Index discovery, upgrades purchasing, world portals, loot equipment/display, fusion, plots/trading, aim assist, and opt-in autofire should build on these boundaries rather than introduce parallel inventories, currencies, or damage paths.

## Animation joints and AJU

- `ReplicatedStorage/Shared/Utils/AnimationJointUtil.luau` is the shared binding and transform-composition boundary for `AnimationConstraint`s. Gameplay systems consume native constraints only.
- Weapon templates in `ReplicatedStorage.Assets.Tools` and the `ReplicatedStorage.Assets.R15Character` type template must store their animated joints as kinematic `AnimationConstraint`s with attachment-local bind frames. Equipment clones those templates without runtime rig conversion.
- Native avatar `AnimationConstraint`, `BallSocketConstraint`, and `NoCollisionConstraint` instances must remain intact. Rig attachments are immutable bind-pose data; procedural animation must never write their `CFrame` values.
- Client procedural poses are applied through `Transform` during `RunService.PreSimulation`, after the animation compositor. Skip those writes when the owning `Animator.EvaluationThrottled` value is true.
- Aim replication sends only target coordinates through the existing unreliable character event. Each client evaluates waist, neck, arm IK, and weapon transforms locally; joint poses must not be replicated from the server.
- Pose conversion uses `originBind:Inverse() * desiredOrigin * desiredTarget:Inverse() * targetBind`, preserving the original look solver, arm IK, weapon positioning, and recoil results without changing attachment frames.
- `GunService` creates the character-to-weapon root as a kinematic constraint. Kinematic mode is required because weapon joints must remain rigid and deterministic rather than physically simulated.

## Networking

`ReplicatedStorage/Shared/Networking` is the contract boundary. `SimpleRemotes` locates remotes, `SimpleRemotesUtil` dispatches action-coded payloads, `RemoteCodes` defines shared action identifiers, and `Protocols` describes binary payload layouts. Buffer encoding and decoding belongs in `Shared/Utils/BufferUtil.luau`.

When changing a network payload, update its shared code/protocol definition and both endpoints together. Treat every client payload as untrusted at the server boundary.

## Data and dependencies

- Static tuning belongs in `ReplicatedStorage/Shared/Constants`; weapon-specific configuration belongs in `ReplicatedStorage/Shared/Weapons`.
- Cross-runtime structural types belong in `ReplicatedStorage/Shared/GameTypes.luau`.
- Third-party code under `ServerStorage/Packages` and generated package indexes is vendored. It is excluded from project lint and workspace diagnostics and should not be edited as application code.

## Validation

- Run Selene from the repository root using `selene .`.
- Run Luau Language Server analysis with the generated sourcemap, current Roblox API definitions, the new solver enabled, and the package exclusions configured in `.vscode/settings.json`.
- `rokit.toml` pins the repository's Selene and StyLua versions. Formatting follows `.stylua.toml`.
