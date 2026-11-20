// Spike 1a: throwaway bridge between Godot (JavaScriptBridge) and Sui wallets.
// Testnet only. No keys are handled here; the wallet signs.
import { Transaction } from '@mysten/sui/transactions';
import { registerSlushWallet } from '@mysten/slush-wallet';
import { getWallets, SUI_TESTNET_CHAIN } from '@mysten/wallet-standard';
import type { Wallet, WalletAccount } from '@mysten/wallet-standard';

const CONNECT = 'standard:connect';
const SIGN_EXEC = 'sui:signAndExecuteTransaction';

type Cb = (json: string) => void;

let connectedWallet: Wallet | null = null;
let connectedAccount: WalletAccount | null = null;

// Registers the Slush web wallet unless the Slush extension is installed.
registerSlushWallet('Godot Sui SDK spike');

function suiWallets(): Wallet[] {
  return getWallets()
    .get()
    .filter(
      (w) =>
        CONNECT in w.features &&
        SIGN_EXEC in w.features &&
        (w.chains as readonly string[]).includes(SUI_TESTNET_CHAIN),
    );
}

function errMsg(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

const SuiBridge = {
  listWallets(): string {
    return JSON.stringify(suiWallets().map((w) => w.name));
  },

  connect(walletName: string, cb: Cb): void {
    (async () => {
      const wallet = suiWallets().find((w) => w.name === walletName);
      if (!wallet) throw new Error('wallet not found: ' + walletName);
      const feature = wallet.features[CONNECT] as {
        connect: () => Promise<{ accounts: readonly WalletAccount[] }>;
      };
      const { accounts } = await feature.connect();
      const account = accounts[0] ?? wallet.accounts[0];
      if (!account) throw new Error('wallet returned no accounts');
      connectedWallet = wallet;
      connectedAccount = account;
      return { address: account.address };
    })().then(
      (r) => cb(JSON.stringify(r)),
      (e) => cb(JSON.stringify({ error: errMsg(e) })),
    );
  },

  // Alias: GDScript's JavaScriptObject inherits Object.connect(), which would shadow a JS method named connect.
  connectWallet(walletName: string, cb: Cb): void {
    SuiBridge.connect(walletName, cb);
  },

  signAndExecuteTransfer(amountMist: number | string, cb: Cb): void {
    (async () => {
      if (!connectedWallet || !connectedAccount) throw new Error('not connected');
      const amount = BigInt(Math.trunc(Number(amountMist)));
      if (amount <= 0n) throw new Error('invalid amount');
      const address = connectedAccount.address;
      const tx = new Transaction();
      tx.setSenderIfNotSet(address);
      const [coin] = tx.splitCoins(tx.gas, [amount]);
      tx.transferObjects([coin], address);
      const feature = connectedWallet.features[SIGN_EXEC] as {
        signAndExecuteTransaction: (input: {
          transaction: Transaction;
          account: WalletAccount;
          chain: string;
        }) => Promise<{ digest: string }>;
      };
      const out = await feature.signAndExecuteTransaction({
        transaction: tx,
        account: connectedAccount,
        chain: SUI_TESTNET_CHAIN,
      });
      return { digest: out.digest };
    })().then(
      (r) => cb(JSON.stringify(r)),
      (e) => cb(JSON.stringify({ error: errMsg(e) })),
    );
  },
};

(window as unknown as { SuiBridge: typeof SuiBridge }).SuiBridge = SuiBridge;
