<img align="right" width="150" height="150" top="0" src="./assets/KALI_K.jpg">

# 🏯 Keep • [![tests](https://github.com/kalidao/keep/actions/workflows/tests.yml/badge.svg)](https://github.com/kalidao/keep/actions/workflows/tests.yml) ![GitHub](https://img.shields.io/github/license/kalidao/keep) ![GitHub package.json version](https://img.shields.io/github/package-json/v/kalidao/keep) ![Solidity version](https://img.shields.io/badge/solidity-%3E%3D%200.8.18-lightgrey)

Tokenized multisig wallet. 

## Blueprint

```ml
lib
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solbase — https://github.com/Sol-DAO/solbase
src
├─ tests
│  └─ ...
├─ KeepToken — "Modern, minimalist, and gas-optimized ERC1155 implementation with Compound-style voting and flexible permissioning scheme"
├─ Keep — "Tokenized multisig wallet"
└─ KeepFactory — "Keep Factory"
```

## Development

[Keep](https://github.com/kalidao/keep) is built with [Foundry](https://github.com/gakonst/foundry).

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
