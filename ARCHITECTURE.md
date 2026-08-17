# Architecture

## Runtime layout

The repository mirrors Roblox DataModel services on disk. `.vscode/generate-sourcemap.ps1` converts those directories into `sourcemap.json` for Luau Language Server resolution. Regenerate the sourcemap after adding, removing, or renaming source files; do not edit the generated JSON by hand.

- `StarterPlayer/StarterPlayerScripts/Client.local.luau` is the client bootstrap. It clones the server-staged interfaces into `PlayerGui`, requires client modules in `Core`, `Controllers`, then `UI` order, and invokes their `init`, `start`, and Studio-only `test` hooks.
- `ServerScriptService/Server.server.luau` is the server bootstrap. It stages `StarterGui` interfaces in `ReplicatedStorage`, requires server modules in `Core` then `Services` order, and invokes the same lifecycle hooks.
- `ReplicatedStorage/Client` contains client-only state, presentation, input, UI, and gameplay controllers.
- `ServerStorage/Server/Core` owns authoritative player data and foundational game systems such as characters, items, equipment, economy, products, collision, bans, rewards, and shutdown saves.
- `ServerStorage/Server/Services` owns server gameplay features that build on the core systems. Gun validation, shot replication, and global instance IDs live here.
- `ReplicatedStorage/Shared` contains code and data safe to require from either runtime: types, constants, weapon definitions, networking contracts, utility modules, and reusable classes.

## Ownership boundaries

- The server is authoritative for persistent state, inventory/equipment changes, damage, ammunition validation, and anti-exploit decisions. Client controllers may predict or present gameplay but must not become the source of truth.
- Shared modules must not depend on client-only or server-only modules. Runtime-specific adapters belong under `ReplicatedStorage/Client` or `ServerStorage/Server`.
- `Core` modules provide foundational state and lifecycle behavior. Feature-specific orchestration belongs in `Controllers` on the client and `Services` on the server.
- Gun responsibilities are split deliberately: `GunController` handles the local weapon lifecycle and presentation, `GunReplicationController` renders other players' weapons, and `BulletTrackingController` simulates local tracer visuals. `GunService` validates gun requests, while `BulletTrackingService` batches server-authorized shot replication.
- Character equipment restoration must wait until `ItemService` has reconciled the player's inventory and default equipped items. Spawn callbacks must also verify that they still belong to the player's current character before cloning tools.
- Global instance references cross the network through `GlobalInstanceService` and `GlobalInstanceController`; consumers should use that mapping instead of inventing parallel instance-ID registries.

## Networking

`ReplicatedStorage/Shared/Networking` is the contract boundary. `SimpleRemotes` locates remotes, `SimpleRemotesUtil` dispatches action-coded payloads, `RemoteCodes` defines shared action identifiers, and `Protocols` describes binary payload layouts. Buffer encoding and decoding belongs in `Shared/Utils/BufferUtil.luau`.

When changing a network payload, update its shared code/protocol definition and both endpoints together. Treat every client payload as untrusted at the server boundary.

## Data and dependencies

- Static tuning belongs in `ReplicatedStorage/Shared/Constants`; weapon-specific configuration belongs in `ReplicatedStorage/Shared/Weapons`.
- Cross-runtime structural types belong in `ReplicatedStorage/Shared/GameTypes.luau`.
- Third-party code under `ServerStorage/Packages` and generated package indexes is vendored. It is excluded from project lint and workspace diagnostics and should not be edited as application code.

## Validation

- Run Selene from the repository root using `selene .`.
- Run Luau Language Server analysis with the generated sourcemap, Roblox API definitions, and the same package exclusions configured in `.vscode/settings.json`.
- `rokit.toml` pins the repository's Selene and StyLua versions. Formatting follows `.stylua.toml`.
