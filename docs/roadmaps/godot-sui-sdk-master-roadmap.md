# Godot–Sui SDK Master Roadmap (working name 떡방앗간)

**Project:** 니가 한국어 못해 (NHMH)
**Scope:** A free, open-source Sui SDK for every Godot developer. NHMH's games are its first users, not its owners.
**Created:** 2026-11-17 (DEV session, from the STRATEGY handoff of 23 Oct – 15 Nov 2026)
**Status:** Frozen master roadmap once approved. Deviations go in project logs; details go in versioned specs.
**Draws on:** `sdk-handoff-dev.md`, `ddeok-master-roadmap.md` (Phase 6), `ddeok-dev-decisions-v0.2.md`, `ddeok-project-log-003.md`.
**Precedence:** the latest SDK project log beats this roadmap where they differ.

Labels: ✅ decided · 🟡 suggested · ❓ open · 🔍 verify · ⚖️ for a professional

---

## 1. Purpose and audience

**Problem.** Godot has no working Sui SDK. The only one, VAR-META-Tech/Sui-Godot-SDK, is an engine module tested on Godot 4.3 that likely relies on JSON-RPC 🔍. Sui disabled JSON-RPC on Foundation mainnet nodes in late July 2026 and removed it from full-node code in mid-October 2026. Unity has several Sui SDKs; Godot has none that works.

**Audience.** Any Godot developer: solo devs, jam games, studios, educational projects. The SDK must be usable without knowing anything about NHMH.

**Goals**
- Connect a player's wallet, read chain data, and send transactions from GDScript, on Web, Windows, Linux, Android and macOS.
- Cover the gaming primitives: coins, NFTs, Kiosk, sponsored transactions, on-chain randomness.
- Install from the Asset Library without compiling anything.
- Free to use for anyone, for anything.

**Non-goals**
- Not a wallet. The SDK never stores players' funds or permanent keys by default.
- Not a backend. It defines interfaces for sponsors and servers; it doesn't run them.
- Not tied to NHMH, DDEOK or any one provider.

## 2. Decisions so far

| Area | Decision | Status |
|---|---|---|
| Purpose | Generic SDK for all Godot developers; NHMH adapts or forks it for its games | ✅ |
| Funding | Apply for a Sui Foundation Developer Grant; SDK milestones = grant milestones | ✅ |
| Licence | As free as possible: anyone can use it fully, without restrictions | ✅ goal · ❓ which licence (§10) |
| Architecture | Option B: GDScript core + wallet bridge; native layer optional later (§4) | ✅ |
| Sui API | gRPC and GraphQL RPC only | ✅ |
| Platforms for v1.0 | Web, Windows, Linux, Android, **macOS** (dropped to "later" if it delays the project too much) | ✅ |
| iOS | A maybe, not a priority | ✅ |
| Wallet model (SDK default) | Players connect their own wallet (Slush and any Wallet Standard wallet) or sign in with zkLogin | ✅ |
| zkLogin in the game | Allowed. The game holds a temporary zkLogin session key, never a permanent key or recovery phrase | ✅ |
| Local keypair signer | Included for tools, bots and tests. Off by default, with clear warnings. NHMH games never use it | ✅ |
| Gas | A sponsor system is needed, and it has to be sustainable | ✅ need · ❓ how (§11) |
| Showcases | Hangul Hiking Trip and Noraebang Night: one NFT item earned in one, used in the other, same wallet | ✅ |
| Distribution (NHMH) | NHMH's own website; the web build matters most | ✅ |
| DDEOK | Continues on its own track; the SDK never waits on it | ✅ |
| Reuse | Use what's usable from VAR-META (§9) | ✅ |
| Collaboration | Contact mattinfra (Sui forum, April 2026 Godot SDK plan) | ✅ |
| Team | One active developer; more may join | ✅ |
| Godot version | Pinned to **4.7.2** (the project's version) | 🟡 · minimum supported version set in M0 |
| Deadline | v1.0 about mid-2027; both NHMH games finished by 2028-01-01 | 🟡 |

## 3. Design principles

1. **GDScript first.** One GDScript API on every platform. Signals for async results.
2. **Wallet-agnostic.** Any Wallet Standard wallet, zkLogin, or a local keypair, all behind one `Signer` interface.
3. **No lock-in.** No NHMH defaults, servers or package IDs. Network, endpoints, sponsor and connect page are all configurable.
4. **Current Sui APIs only.** gRPC for execution, GraphQL for reads. No JSON-RPC anywhere.
5. **Installs without compiling.** Pure GDScript plus a bundled JS file. A native layer may come later as an optional speed-up.
6. **Safe by default.** No player keys unless the developer explicitly opts in. The SDK shows what's being signed where it can; the wallet always does.
7. **Built on Mysten's official SDKs** where possible (TypeScript SDK, dApp Kit), so transaction building isn't reimplemented and drifts less.
8. **Documented in English and Korean** from M1, not just at release.

## 4. Architecture

```
Developer's game
 └ SDK: GDScript API (Sui autoload + classes)
    ├ Client
    │  ├ Reads: GraphQL RPC over HTTPRequest (all platforms)
    │  └ Network config: mainnet / testnet / devnet / localnet / custom
    ├ Transactions: PTB "intents" described as data (move calls, transfers, splits, merges)
    ├ Signer interface (one adapter per platform or method)
    │  ├ WebWalletSigner     Web: JavaScriptBridge → bundled JS (TS SDK + dApp Kit core + Slush)
    │  ├ BrowserHandoffSigner Desktop: system browser → connect page → loopback 127.0.0.1
    │  ├ AndroidSigner       Slush app link or browser → connect page → app link back
    │  ├ ZkLoginSigner       OAuth in the system browser → session key in the game → proof
    │  │                     (Enoki adapter first; self-managed salt and prover as an option)
    │  └ KeypairSigner       Tools, bots, tests only. Off by default
    ├ Sponsor interface (§11)
    └ Game layer: Coin, NFT + Display, Kiosk, randomness helpers

Connect page template (open source, self-hosted by each developer)
 └ Same JS bundle as the web signer. Builds the transaction from the intent,
   asks the wallet to sign, returns the result to the game.

Optional, later: a native GDExtension (ours or mattinfra's) behind the same API,
for offline transaction building, BCS decoding and gRPC streaming.
```

**Why this shape.** The player's wallet signs every transaction, so each one already passes through a wallet surface. A web page running Mysten's TypeScript SDK and dApp Kit is the one place where every Sui wallet works today. Native platforms reach that page instead of reimplementing the transaction stack.

**Known costs**
- On desktop, signing with an external wallet opens a browser tab. zkLogin avoids this once the session is set up.
- No gRPC streaming in the core; games poll for events. The optional native layer can add streaming.

## 5. Feature scope

**Core (M1–M3)**
- Connect and disconnect; account and address; network switching; session persistence.
- Reads: objects, owned objects by type, coins and balances, dynamic fields, transactions, events (polling).
- Transactions: intents for move calls, transfers, split and merge coins; dry run; sign; sign and execute; personal message signing.
- Errors and retries surfaced as signals with clear error types.

**Game layer (M4)**
- Coins: balances, transfers, formatting with decimals and the coin registry.
- NFTs: owned NFTs by type, Display metadata, image loading into Godot textures.
- Kiosk: read listings, buy, list, delist; royalty rules respected.
- Sponsored transactions through the sponsor interface.
- On-chain randomness: helpers to call randomness-using entry functions and read results.

**Out of scope**
- Wallet key storage beyond zkLogin sessions and the opt-in keypair signer.
- Hosting backends, sponsors or indexers.
- Game-specific logic (tokens, stores, reward rules, anti-cheat).
- Move contract development tools.

## 6. Platforms and order

| Order | Platform | Signing path | Phase |
|---|---|---|---|
| 1 | **Web** | In-page wallet (Slush extension, Slush web app, other Wallet Standard wallets), zkLogin | M1 |
| 2 | **Windows, Linux, macOS** | Browser handoff with loopback; zkLogin | M2 |
| 3 | **Android** | Slush app link or browser + app link back; zkLogin. Path chosen by the M0 spike | M3 |
| Later | iOS | Same pattern as Android 🔍 | Follow-on, maybe |

**macOS rule.** macOS ships in M2 unless it delays the project too much. Then it moves to follow-on and the reason is logged. Testing needs Mac hardware 🔍.

**Web export.** Plan for a single-threaded Godot web export, because the COOP/COEP headers that threads need can break wallet popups 🔍.

## 7. Phases and gates (= grant milestones)

One phase at a time. Each phase ends at its gate before the next begins. Dates are targets 🟡.

### M0: Spec, spikes and kickoff (upfront tranche) · Dec 2026
- Architecture spec v0.1 and API design v0.1 (versioned production docs).
- Public repo with licence, CONTRIBUTING, code of conduct, CI skeleton.
- **Spike 1:** desktop browser handoff with loopback signs a testnet transaction on Windows and Linux (Slush extension and Slush web app).
- **Spike 2:** an Android round trip on a real phone (Slush app link and Custom Tabs), returning to the game.
- **Spike 3:** zkLogin session from Godot (OAuth in the system browser, Enoki adapter).
- Read VAR-META's Rust2C `Cargo.toml` to confirm its transport.
- Contact mattinfra; record the outcome.
- Set the minimum supported Godot version.
- **Gate:** all three spikes sign a testnet transaction (explorer links and recordings); spec approved; no blocking ❓.

### M1: Web · Jan–Feb 2027
- `WebWalletSigner`, GraphQL client, transaction intents, sign and execute, event polling.
- `ZkLoginSigner` on web.
- Connect page template v0.1.
- Starter project (generic) exported to web.
- Docs EN + KO: install, connect, read, send.
- **Gate:** a public testnet demo URL works; an automated Playwright test passes on localnet with a CI-only test wallet.

### M2: Desktop (Windows, Linux, macOS) · Mar 2027
- `BrowserHandoffSigner` with state nonce and loopback; `ZkLoginSigner` on desktop.
- `KeypairSigner` (off by default; warnings in the editor and the docs).
- **Gate:** CI builds all three desktop exports; the same test transactions pass from each OS. macOS may move to follow-on under the §6 rule.

### M3: Android · Apr 2027
- `AndroidSigner` (the path chosen in M0); zkLogin on Android.
- **Gate:** the device checklist passes on two Android versions.

### M4: Game layer and showcases · Apr–May 2027
- Coin, NFT + Display, Kiosk, sponsor interface with adapters, randomness helpers.
- Demo item contract (generic, in the SDK repo) for the cross-game showcase.
- **Showcase:** an item earned in Hangul Hiking Trip works in Noraebang Night, same wallet, on testnet, on web, desktop and Android.
- **Gate:** the showcase passes on every v1.0 platform; the starter project covers every game-layer feature.

### M5: v1.0 · Jun 2027
- API freeze and semantic versioning from 1.0.0.
- Docs EN + KO complete; at least 3 tutorials (connect and read; NFTs and Kiosk; sponsored transactions).
- Asset Library release 🔍 (Godot 4.7 introduced a new Asset Store; check submission rules).
- **Gate:** a developer new to the SDK goes from an empty project to a first signed testnet transaction in under 15 minutes by following the docs.

### Follow-on (unfunded or a second grant)
- iOS (maybe).
- Optional native GDExtension layer, ideally with mattinfra.
- Other wallets' native mobile flows as they appear.

## 8. Showcases

1. **Starter project** (generic, MIT-style like the SDK): connect, read balances, view NFTs, buy from a Kiosk, sponsored mint. Anyone copies it.
2. **NHMH cross-game item:** earned in *Hangul Hiking Trip*, used in *Noraebang Night*, same wallet. Proves that items move between games on Sui.

## 9. Reuse and ecosystem

**VAR-META-Tech/Sui-Godot-SDK (Apache-2.0)**
- Keep as reference: API naming (`sui_builder`, `sui_nfts`), demo scene structure, its feature list as a coverage checklist.
- Drop: the engine module, Rust2C (likely on a dead transport 🔍), in-app wallet generation and import, multisig.
- **No code copied** 🟡, so no Apache NOTICE obligations and the licence choice stays free. Credited in the README.

**mattinfra** (Sui forum, 9 Apr 2026: Rust GDExtension wrapping sui-rust-sdk, grant planned)
- Contact in M0. Possible outcomes: collaborate (their Rust layer becomes our optional native layer), coordinate (split scope), or proceed separately with clear differences stated in the grant.

**Mysten SDKs.** TypeScript SDK, dApp Kit core, Slush wallet SDK, Enoki SDK; sui-rust-sdk for any later native layer.

**Precedents.** Sui's Unity and Unreal SDKs; Dojo's Godot SDK (GDExtension); Unity WebGL wallet bridges built on the same JS-bridge pattern.

## 10. Licence ❓

Goal ✅: anyone can use it fully, without restrictions.

| Option | Freedom | Notes |
|---|---|---|
| MIT | Very high | Matches Godot. No patent grant |
| Apache-2.0 | High | Patent grant; NOTICE file rules; matches Mysten SDKs |
| MIT OR Apache-2.0 (dual) | Very high | User picks either; the Rust ecosystem's convention |
| 0BSD / Unlicense / MIT-0 | Highest (no attribution needed) | Less familiar to some companies and reviewers |

**Dependency licences:** Godot MIT; sui-rust-sdk Apache-2.0; Mysten TypeScript SDK 🔍; dApp Kit, Slush and Enoki SDKs 🔍; gdext MPL-2.0 (only if a native layer is added; MPL files stay MPL).
**Decide before the repo goes public in M0.** ⚖️ final review.

## 11. Gas sponsorship and backend

- The SDK defines a `Sponsor` interface: send transaction kind → receive sponsored bytes → player signs → execute.
- **Adapters:** Enoki, Shinami 🔍, and a **reference self-hosted sponsor** (separate small repo, same licence) with allowlists of transaction types, per-address rate limits, budget caps and separate testnet/mainnet keys.
- Sponsor keys never live in a game client, repo or chat.
- **Sustainability** (who pays, caps, costs per player) is decided in a STRATEGY session ❓, for the SDK docs and for NHMH separately.

## 12. Testing and CI

- GDScript headless tests (the same style as the NHMH games) against **localnet** (`sui start` with faucet) in CI.
- A smaller smoke suite against testnet, on a schedule.
- Web: export, serve and drive with Playwright, using a CI-only test wallet. Its key exists only in CI secrets.
- Desktop and Android: CI builds; signing flows checked with manual checklists per release.
- CI matrix: Web, Windows, Linux, macOS, Android.
- A mock backend for tests, so developers can test their own games offline.

## 13. Repo, docs and releases

- New repo under the NHMH GitHub org, not a fork of VAR-META.
- Public name ❓. Using "Sui" in the name may be subject to Sui brand rules 🔍.
- Docs in English and Korean: API reference, guides, tutorials, the connect-page hosting guide.
- Semantic versioning; a CHANGELOG; supported Godot versions listed per release.
- Releases on GitHub and the Asset Library 🔍.

## 14. Impact and sustainability (for the grant)

**Impact metrics** 🟡
- Asset Library downloads and GitHub stars, forks and clones.
- Number of external projects using the SDK (opt-in showcase list).
- Issues closed and response time.
- Tutorials completed (docs analytics, if privacy allows).

**Sustainability** 🟡
- Maintenance after the grant: NHMH depends on the SDK for its own games, so it keeps being maintained.
- Contributor guide, good-first-issues, Korean and English community channels.
- Follow-on funding: a second grant for iOS or the native layer; donations.

## 15. Risks

| # | Risk | Response |
|---|---|---|
| 1 | **Capacity:** one active developer, three tracks (two games, DDEOK, SDK) | Option B keeps the SDK small; macOS and iOS can drop; grant funds focus time |
| 2 | **Android return path** unproven; Google blocks OAuth in embedded WebViews 🔍 | Spike 2 in M0 before M3 is promised |
| 3 | **Desktop loopback** may hit Chrome's Private Network Access rules 🔍 | Spike 1; fallbacks: OAuth-style top-level redirect, or a relay |
| 4 | **Web threads:** COOP/COEP can break wallet popups 🔍 | Single-threaded web export |
| 5 | **Duplicate grant** with mattinfra | Contact in M0; collaborate or state the differences |
| 6 | **Grant mechanics:** payment may be in SUI, not USD 🔍; KYB may need a legal entity ⚖️ | Check before the budget; budget conservatively |
| 7 | **Sui API churn** (TS SDK 2.x, young GraphQL schema) | Pin versions; localnet CI catches breaks |
| 8 | **Connect page phishing** | Self-hosted on the developer's own domain; state nonce; wallet always shows what is signed |
| 9 | **zkLogin session key** in the game | Memory-only by default; short expiry; documented threat model |
| 10 | **KeypairSigner misuse** | Off by default; editor and runtime warnings; not used in NHMH games |
| 11 | **macOS** needs Apple hardware and notarization for test builds 🔍 | The §6 drop rule |
| 12 | **Asset Store changes** in Godot 4.7 🔍 | Check submission rules before M5 |

## 16. How NHMH uses the SDK

- NHMH games depend on the SDK (or a fork for game-specific changes) as an ordinary user would.
- A separate `ddeok` addon (AGPL-3.0-only, in the DDEOK repo) sits on top: package IDs, claims, stores, item effects.
- The NHMH sponsor and reward signer run on the ddeok.xyz VPS, built on the SDK's sponsor interface.
- The on-chain/off-chain toggle, virtual items and anti-cheat stay in game code.
- DDEOK's phases continue on their own schedule; the SDK's showcase uses its own demo item contract.
- NHMH's wallet rule: Slush (or any Wallet Standard wallet) or zkLogin; never the `KeypairSigner`.

## 17. Open questions, verification, professional review

**Open ❓**
1. Licence (§10).
2. Public name (§13).
3. Gas sponsorship sustainability (§11), in a STRATEGY session.
4. Grant budget by line item (STRATEGY).
5. Outcome of contacting mattinfra.
6. Android signing path (M0 spike 2).
7. Minimum supported Godot version (M0).

**To verify 🔍**
- Rust2C's RPC transport.
- Licences of the Mysten TypeScript SDK, dApp Kit, Slush wallet SDK and Enoki SDK.
- Grant payment currency (SUI or USD) and current application requirements.
- Chrome Private Network Access and loopback from an HTTPS page.
- Slush in-app browser and Custom Tabs returning to an Android app.
- Google OAuth policy on embedded WebViews.
- Godot web export without threads and wallet popups.
- Godot 4.7 Asset Store submission rules.
- Sui brand rules for names using "Sui".
- macOS test and notarization requirements.
- Enoki and Shinami pricing.

**For a professional ⚖️**
- Final licence choice and dependency compatibility.
- Grant agreement, KYB and the legal entity.
- Tax on grant income.

## 18. Deviations from `ddeok-master-roadmap.md` Phase 6 (for the next log)

- Phase 6 becomes a **standalone public SDK**, not NHMH-only integration code.
- **iOS deferred** to a maybe; **macOS added**.
- Wallet support now includes **in-game zkLogin** (temporary session key) and an opt-in **keypair signer** for tools and tests.
- Phase 6's gate ("full playthrough in both modes on PC and mobile, both games") stays with NHMH's game work; the SDK's gates are in §7.

## Sources (checked 2026-11-15 to 11-17)

- Sui JSON-RPC Migration Guide: https://docs.sui.io/develop/accessing-data/json-rpc-migration
- Sui GraphQL Migration Cookbook (endpoints, incl. testnet): https://docs.sui.io/develop/accessing-data/graphql/graphql-migration-cookbook
- Mysten SDK, SuiGrpcClient (gRPC-web default in browsers): https://sdk.mystenlabs.com/sui/clients/grpc
- Godot 4.7.2 maintenance release: https://gamedev.net/news/5170-maintenance-release-godot-472/
- VAR-META-Tech/Sui-Godot-SDK: https://github.com/VAR-META-Tech/Sui-Godot-SDK
- Sui forum, "Building a modern Godot SDK for Sui": https://forums.sui.io/t/building-a-modern-godot-sdk-for-sui-gauging-interest/49255
- gdext licence (MPL-2.0) and wasm status: https://docs.rs/crate/godot/0.5.2/source/Cargo.toml
- MystenLabs/sui-rust-sdk (Apache-2.0): https://github.com/MystenLabs/sui-rust-sdk
- Sui docs, Slush: https://docs.sui.io/onchain-finance/asset-custody/wallets/slush
- Sui docs, zkLogin wallets and Enoki: https://docs.sui.io/onchain-finance/asset-custody/wallets/zk-login-wallets
- Sui forum, Apply for a Sui Developer Grant: https://forums.sui.io/t/apply-for-a-sui-developer-grant/58
