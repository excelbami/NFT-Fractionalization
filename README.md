# 🧩 NFT Fractionalization Smart Contract

> Transform your precious NFTs into tradeable fractions! Split, own, trade, and reconstruct NFTs with ease.

## 🌟 What is NFT Fractionalization?

NFT Fractionalization allows you to split a single NFT into multiple fungible tokens (fractions). This enables:
- 💰 **Shared ownership** of expensive NFTs
- 🏪 **Liquid markets** for NFT portions
- 🎯 **Accessible investing** in high-value digital assets
- 🔄 **Reconstruction** when owning all fractions

## ✨ Key Features

- 🧩 **Fractionalize** any NFT into custom amounts
- 💱 **Trade fractions** like regular fungible tokens
- 🔄 **Reconstruct** original NFT by collecting all fractions
- 💵 **Price discovery** through fraction trading
- 🔒 **Secure custody** of original NFTs in contract
- 💎 **Instant Buyout** mechanism for acquiring complete ownership

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Stacks blockchain

### Installation

```bash
git clone <your-repo>
cd NFT-Fractionalization
clarinet check
```

## 📋 Usage

### 1. Fractionalize an NFT

```clarity
(contract-call? .nft-fractionalization fractionalize-nft 
  .my-nft-contract  ; NFT contract
  u1                ; NFT ID
  u1000             ; Total fractions
  u100              ; Price per fraction (in microSTX)
)
```

### 2. Buy Fractions

```clarity
(contract-call? .nft-fractionalization buy-fractions
  .my-nft-contract  ; NFT contract principal
  u1                ; NFT ID
  u50               ; Number of fractions to buy
)
```

### 3. Sell Fractions (List for Sale)

```clarity
(contract-call? .nft-fractionalization sell-fractions
  .my-nft-contract  ; NFT contract principal
  u1                ; NFT ID
  u25               ; Fractions to sell
  u120              ; Price per fraction
)
```

### 4. Reconstruct NFT

```clarity
(contract-call? .nft-fractionalization reconstruct-nft
  .my-nft-contract  ; NFT contract
  u1                ; NFT ID
)
```

### 5. Propose a Buyout

```clarity
(contract-call? .nft-fractionalization propose-buyout
  .my-nft-contract  ; NFT contract principal
  u1                ; NFT ID
  u150              ; Price per fraction (premium over market)
)
```

### 6. Accept a Buyout Offer

```clarity
(contract-call? .nft-fractionalization accept-buyout
  .my-nft-contract  ; NFT contract principal
  u1                ; NFT ID
  u25               ; Number of fractions to sell
)
```

### 7. Cancel a Buyout Proposal

```clarity
(contract-call? .nft-fractionalization cancel-buyout
  .my-nft-contract  ; NFT contract principal
  u1                ; NFT ID
)
```

## 🔍 Read-Only Functions

### Get Fraction Balance
```clarity
(contract-call? .nft-fractionalization get-user-fraction-balance
  'SP1234...ABCD    ; User principal
  .nft-contract     ; NFT contract
  u1                ; NFT ID
)
```

### Get NFT Info
```clarity
(contract-call? .nft-fractionalization get-fractionalized-nft
  .nft-contract     ; NFT contract
  u1                ; NFT ID
)
```

### Get Token Balance
```clarity
(contract-call? .nft-fractionalization get-balance
  'SP1234...ABCD    ; User principal
)
```

### Get Buyout Proposal
```clarity
(contract-call? .nft-fractionalization get-buyout-proposal
  .nft-contract     ; NFT contract
  u1                ; NFT ID
)
```

## 🏗️ Contract Architecture

```
NFT Owner → Fractionalize → Fraction Tokens
    ↓
Multiple Fraction Holders ← → Trade Fractions
    ↓                          ↓
    ↓                    Buyout Proposal
    ↓                          ↓
    ↓                    Accept Buyout ← Premium Price
    ↓                          ↓
Collect All Fractions → Reconstruct Original NFT
```

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Test individual functions:

```bash
clarinet console
```

## 📊 Contract Functions

| Function | Description | Access |
|----------|-------------|--------|
| `fractionalize-nft` | Split NFT into fractions | Public |
| `buy-fractions` | Purchase fraction tokens | Public |
| `sell-fractions` | List fractions for sale | Public |
| `reconstruct-nft` | Rebuild original NFT | Public |
| `propose-buyout` | Create buyout offer | Public |
| `accept-buyout` | Sell fractions to buyout | Public |
| `cancel-buyout` | Cancel buyout proposal | Public |
| `transfer` | Transfer fraction tokens | Public |
| `get-balance` | Check fraction balance | Read-only |
| `get-fractionalized-nft` | Get NFT details | Read-only |
| `get-buyout-proposal` | Get buyout offer details | Read-only |

## ⚠️ Important Notes

- 🔐 Original NFT is held in contract custody during fractionalization
- 🧮 You need **ALL** fractions to reconstruct the original NFT
- 💰 Fraction prices are set by the original owner
- 🔄 Transfers follow SIP-010 fungible token standard
- 💎 Buyout mechanism enables fast acquisition without collecting all fractions individually
- 🚀 Once all fractions are acquired via buyout, the initiator can reconstruct the NFT

## 🛡️ Security Features

- ✅ Owner verification for NFT operations
- ✅ Balance checks before transfers
- ✅ Protection against double fractionalization
- ✅ Secure NFT custody in contract

## 🎯 MVP Limitations

This is a Minimum Viable Product with:
- Basic fractionalization and reconstruction
- Simple price discovery mechanism
- No advanced trading features
- No governance mechanisms

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📜 License

MIT License - see LICENSE file for details

---

**Built with ❤️ for the Stacks ecosystem**
