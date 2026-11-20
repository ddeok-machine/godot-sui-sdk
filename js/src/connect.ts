// Spike 1b: connect page. Opened by a native Godot build; the wallet signs a testnet self-transfer
// and the result goes back to the game over 127.0.0.1. Testnet only.
import { connectWallet, errMsg, listWalletNames, transferToSelf } from './wallet';

const MAX_AMOUNT_MIST = 100_000_000n; // spike safety cap: 0.1 SUI

const $ = (id: string): HTMLElement => document.getElementById(id) as HTMLElement;
const say = (id: string, text: string): void => {
  $(id).textContent = text;
};

const params = new URLSearchParams(window.location.search);
const action = params.get('action');
const network = params.get('network');
const state = params.get('state') ?? '';
const portStr = params.get('port') ?? '';
const amountStr = params.get('amount_mist') ?? '';

function validate(): { port: number; amount: bigint } | string {
  if (action !== 'transfer') return 'unsupported action';
  if (network !== 'testnet') return 'testnet only';
  if (!/^\d{1,5}$/.test(portStr) || Number(portStr) < 1024 || Number(portStr) > 65535) return 'bad port';
  if (!/^[0-9a-f]{16,128}$/.test(state)) return 'bad state';
  if (!/^\d{1,18}$/.test(amountStr)) return 'bad amount';
  const amount = BigInt(amountStr);
  if (amount <= 0n || amount > MAX_AMOUNT_MIST) return 'amount out of range';
  return { port: Number(portStr), amount };
}

async function returnToGame(port: number, digest: string): Promise<void> {
  const base = `http://127.0.0.1:${port}/cb`;
  try {
    const res = await fetch(base, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ state, digest }),
    });
    if (!res.ok) throw new Error('game replied ' + res.status);
    say('delivery', 'Delivered to the game via fetch POST.');
  } catch (e) {
    say('delivery', 'fetch failed (' + errMsg(e) + '); redirecting to the game...');
    window.location.href = `${base}?state=${encodeURIComponent(state)}&digest=${encodeURIComponent(digest)}`;
  }
}

function main(): void {
  const v = validate();
  if (typeof v === 'string') {
    say('status', 'Invalid request: ' + v);
    return;
  }
  say('status', `Transfer ${v.amount} MIST to yourself on testnet.`);
  const list = $('wallets');
  const names = listWalletNames();
  if (names.length === 0) say('status', 'No Sui wallet found.');
  for (const name of names) {
    const btn = document.createElement('button');
    btn.textContent = 'Connect ' + name;
    btn.onclick = async () => {
      btn.disabled = true;
      try {
        const address = await connectWallet(name);
        say('status', 'Connected: ' + address);
        const send = document.createElement('button');
        send.textContent = 'Sign and send';
        send.onclick = async () => {
          send.disabled = true;
          try {
            const digest = await transferToSelf(v.amount);
            say('digest', 'Digest: ' + digest);
            await returnToGame(v.port, digest);
          } catch (e) {
            say('status', 'Failed: ' + errMsg(e));
            send.disabled = false;
          }
        };
        $('actions').appendChild(send);
      } catch (e) {
        say('status', 'Connect failed: ' + errMsg(e));
        btn.disabled = false;
      }
    };
    list.appendChild(btn);
  }
}

main();
