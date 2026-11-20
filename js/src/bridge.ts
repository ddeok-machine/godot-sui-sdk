// Spike 1a: throwaway bridge between Godot (JavaScriptBridge) and Sui wallets. Testnet only.
import { connectWallet, errMsg, listWalletNames, transferToSelf } from './wallet';

type Cb = (json: string) => void;

function reply<T>(p: Promise<T>, cb: Cb): void {
  p.then(
    (r) => cb(JSON.stringify(r)),
    (e) => cb(JSON.stringify({ error: errMsg(e) })),
  );
}

const SuiBridge = {
  listWallets(): string {
    return JSON.stringify(listWalletNames());
  },

  connect(walletName: string, cb: Cb): void {
    reply(
      connectWallet(walletName).then((address) => ({ address })),
      cb,
    );
  },

  // Alias: GDScript's JavaScriptObject inherits Object.connect(), which would shadow a JS method named connect.
  connectWallet(walletName: string, cb: Cb): void {
    SuiBridge.connect(walletName, cb);
  },

  signAndExecuteTransfer(amountMist: number | string, cb: Cb): void {
    reply(
      transferToSelf(BigInt(Math.trunc(Number(amountMist)))).then((digest) => ({ digest })),
      cb,
    );
  },
};

(window as unknown as { SuiBridge: typeof SuiBridge }).SuiBridge = SuiBridge;
