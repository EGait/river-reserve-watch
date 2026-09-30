# River Reserve Watch

An independent monitor and verification of [River's Proof of Reserves](https://river.com/reserves), built from public data.

**Live site:** (https://river-reserve-watch.vercel.app/)

## What it does

- **Live reserve balance.** Reads River's published cold storage address from the mempool.space API and refreshes every 5 minutes.
- **Proof of Reserves history.** Charts assets and liabilities from every monthly attestation on river.com/reserves, with the surplus and coverage for each month.
- **Movement labels.** Classifies each transaction touching the reserve:
  - **Inflow / Outflow**: funds entering or leaving the tracked address
  - **Internal**: moves between tracked addresses
  - **Possible internal move**: a round amount of 10 BTC or more to or from an untracked address, the usual shape of a treasury transfer. Verify against river.com/reserves before treating it as an outflow.
  - **Ownership proof**: the small monthly transaction River sends to prove it controls the reserve
- **Reconciliation.** Shows the net movement at the reserve address since the latest attestation.

## Independent verification: September 1, 2026 proof

Snapshot block: 965,052

| Part | Result | How |
| --- | --- | --- |
| Assets on-chain | Reconciled | The reserve address balance matches attested assets of 33,737.53513283 BTC to the satoshi, after the movements since the snapshot. |
| Liabilities add up | Verified | Rebuilt River's Merkle sum tree: 2,097,151 parent nodes checked, 0 sum and 0 hash mismatches. The total of 33,498.71382005 BTC matches published liabilities. |
| River controls the address | Verified | The proof transaction sent 0.04034917 BTC, matching the last seven digits of block 965,052's largest coinbase output (3.14034917 BTC). |

## Verify the liabilities yourself

`verify-liabilities.ps1` checks River's Proof of Liabilities file on Windows, with nothing to install. It follows the same rules as River's [open-source proof-of-reserves code](https://github.com/RiverFinancial/proof-of-reserves): every parent node's value must equal the sum of its two children, and its hash must equal SHA-256 of the left hash, left value, right hash, and right value (values as 8-byte little-endian).

1. Download the liabilities CSV from river.com/reserves (Verify Liabilities, then Verify on your computer) and unzip it.
2. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\verify-liabilities.ps1 -Path .\river_liabilities.csv
   ```

3. Look for `VERIFIED` in the output. The script only reads the file; it makes no network calls and changes nothing.

The liabilities file is not included in this repo. Download it from River.

## Limitations

- **Balances, not a full audit.** The live dashboard shows on-chain assets only. Liabilities change daily, so coverage is exact only as of each attestation date.
- **Inclusion is per client.** The liabilities check confirms the file is internally consistent and matches the published total. Only individual clients can confirm their own balances are included, using their account key.
- **Leaves aren't accounts.** River splits balances and pads the tree to a power of two, so the number of leaves is not a customer count.
- **Movement labels are heuristics.** "Possible internal move" and "Likely ownership proof" are best guesses until checked by hand.

## Data sources

- Balances and transactions: [mempool.space API](https://mempool.space/docs/api)
- Attestations and reserve address: [river.com/reserves](https://river.com/reserves)

## Updating

- **New monthly proof:** add a line to the top of `PROOFS` in `index.html`.
- **New reserve address:** add it to `ADDRESSES` in `index.html`.
- **Verified ownership proof:** add its transaction ID to `VERIFIED_PROOF_TXS`.

## Disclaimer

Not affiliated with or endorsed by River Financial. Built for learning and verification only.
