# MKR v1 Verification

Byte-for-byte bytecode verification for the **original Maker Governance Token (MKR v1)** at `0xc66ea802717bfb9833400264dd12c2bceaa34a6d`.

| Field | Value |
|---|---|
| Contract | `0xc66ea802717bfb9833400264dd12c2bceaa34a6d` |
| Network | Ethereum Mainnet |
| Block | 1,233,109 |
| Deployed | Mar 28, 2016 |
| Deployer EOA | `0x5c83154239485698b694b8cd5953e8669d07b49e` |
| Created via factory | `0x12bcc9daffda452b6c4b0a1571360925a64fcc79` (`DSTokenFactory.buildDSTokenFrontend()`) |
| Compiler | soljson v0.3.2+commit.81ae2a78 (any of v0.2.1+, v0.2.2, v0.3.0+, v0.3.1, v0.3.2 — and v0.3.0-nightly.2016.3.18) |
| Optimizer | OFF |
| Runtime match | ✅ EXACT (3040 bytes) |
| Creation match | ✅ EXACT (3200 bytes init+runtime, byte-identical to embedded code in on-chain factory at offset 12,204) |

## Verification

```bash
./verify.sh
```

Expected output: `✅ EXACT BYTECODE MATCH (3040 bytes)` with `sha256: 9748ebea1614ef4f54d273514e94d18bb1b0baae6c8aa2d9b3e0dd224147cec6`.

## What this contract is

`DSTokenFrontend` is a thin proxy in front of an upgradeable `DSTokenController` and back-end balance/approval databases — the original ERC-20 Maker (MKR) governance token, deployed by MakerDAO before they migrated to the v2 MKR contract. It implements the standard ERC-20 surface (`transfer`, `balanceOf`, `approve`, `allowance`, etc.) by delegating every call to the `_controller`, plus auth-protected admin functions (`setController`, `updateAuthority`, `emitTransfer`, `emitApproval`).

## Source provenance

Based on dappsys 0.1.2 (commit `8ddd3f381ef526c770be3ba7bdd783e7fbbf04a5`, tag `0.1.2`, Mar 22 2016) — the dappfile in that commit lists the on-chain factory address verbatim, confirming the codebase. However the **published** dappsys 0.1.2 source does NOT compile to the on-chain bytecode: the auth state vars and implementation were extracted into a base mixin `DSAuthorized` *after* deployment, which changes solc's function-body emission order.

The verifying source in this repo restores the pre-refactor structure: `DSAuthorized` is a pure interface (modifiers + abstract function declarations only), and the auth state (`_auth_mode`, `_authority`) plus implementations (`updateAuthority`, `isAuthorized`, constructor) live inside `DSTokenFrontend` directly. This produces byte-identical runtime AND creation code.

The cracking process is documented in detail at https://github.com/cartoonitunes/eth-bytecode-cracker/tree/main/targets/mkr-v1-0xc66ea802 — see the README in that directory for the 16 source mutations and 30+ native solc binaries that were tried before this structure was identified.

## Deployment record on-chain

The factory `0x12bcc9da…`'s `buildDSTokenFrontend()` deployed this contract on Mar 28 2016 in tx [included in block 1,233,109]. The factory was itself deployed Mar 20 2016, and its embedded DSTokenFrontend init+runtime sections (offsets 12,204–18,604 of the factory runtime) are byte-identical to the standalone init+runtime produced from `DSTokenFrontend.sol` here.
