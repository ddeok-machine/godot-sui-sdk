// Shared wallet logic for the spikes (throwaway). Testnet only. No keys are handled here; the wallet signs.
import { Transaction } from '@mysten/sui/transactions';
import { registerSlushWallet } from '@mysten/slush-wallet';
import { getWallets, SUI_TESTNET_CHAIN } from '@mysten/wallet-standard';
import type { Wallet, WalletAccount } from '@mysten/wallet-standard';

const CONNECT = 'standard:connect';
const SIGN_EXEC = 'sui:signAndExecuteTransaction';

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

export function listWalletNames(): string[] {
  return suiWallets().map((w) => w.name);
}

/** Calls the wallet's standard:connect; resolves with the first account's address. */
export async function connectWallet(walletName: string): Promise<string> {
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
  return account.address;
}

/** Asks the connected wallet to sign and execute a transfer of amountMist from gas to the account itself. */
export async function transferToSelf(amountMist: bigint): Promise<string> {
  if (!connectedWallet || !connectedAccount) throw new Error('not connected');
  if (amountMist <= 0n) throw new Error('invalid amount');
  const address = connectedAccount.address;
  const tx = new Transaction();
  tx.setSenderIfNotSet(address);
  const [coin] = tx.splitCoins(tx.gas, [amountMist]);
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
  return out.digest;
}

export function errMsg(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}
