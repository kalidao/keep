<img align="right" width="150" height="150" top="0" src="./assets/KALI_K.jpg">

# multi-sig • [![tests](https://github.com/kalidao/multi-sig/actions/workflows/tests.yml/badge.svg)](https://github.com/kalidao/multi-sig/actions/workflows/tests.yml) ![GitHub](https://img.shields.io/github/license/kalidao/multi-sig) ![GitHub package.json version](https://img.shields.io/github/package-json/v/kalidao/multi-sig) ![Solidity version](https://img.shields.io/badge/solidity-%3E%3D%200.8.4-lightgrey)

Tokenized multisig wallet. 

Modified from [MultiSignatureWallet](https://github.com/SilentCicero/MultiSignatureWallet/blob/master/MultiSignatureWallet.yul), [LilGnosis](https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol), [Gnosis Safe](https://github.com/safe-global/safe-contracts/tree/main/contracts), [Baal](https://github.com/Moloch-Mystics/Baal/blob/feat/baalZodiac/contracts/Baal.sol) and [Compound Governance](https://github.com/compound-finance/compound-protocol/tree/master/contracts/Governance)

## Blueprint

```ml
lib
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solbase — https://github.com/Sol-DAO/solbase
src
├─ tests
│  └─ ...
├─ KeepToken — "Modern, minimalist, and gas-optimized ERC1155 implementation with Compound-style voting and flexible permissioning scheme"
├─ Keep — "EIP-712 multi-signature wallet with ERC1155 interface"
└─ KeepFactory — "Keep Factory"
```

## Development

[multi-sig](https://github.com/kalidao/multi-sig) is built with [Foundry](https://github.com/gakonst/foundry).

**Setup**
```bash
forge install
```

**Building**
```bash
forge build
```

**Testing**
```bash
forge test
```

**Configure Foundry**

Using [foundry.toml](./foundry.toml), Foundry is easily configurable.

For a full list of configuration options, see the Foundry [configuration documentation](https://github.com/gakonst/foundry/blob/master/config/README.md#all-options).

## License

[MIT](https://github.com/kalidao/multi-sig/blob/main/LICENSE)
