# Rules for future sessions

- Generic SDK: no NHMH, DDEOK or game-specific names, IDs or URLs anywhere in `addons/`.
- Sui APIs: gRPC and GraphQL RPC only. Never JSON-RPC.
- Never create, request, print or store private keys, recovery phrases or API keys. Testnet/devnet/localnet only during M0.
- `spikes/` is throwaway and never imported by `addons/`.
- Do not run `git add`, `git commit` or `git push`. The user commits.
- Check Godot and Sui APIs against current docs, not memory; say when something is unverified.
- Windows: quote paths; files use LF.
- The repo is public: never commit secrets, wallet addresses of real users, or private notes.
