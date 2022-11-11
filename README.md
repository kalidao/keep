<img align="right" width="150" height="150" top="0" src="./assets/KALI_K.jpg">

# 🏯 Keep • [![tests](https://github.com/kalidao/keep/actions/workflows/tests.yml/badge.svg)](https://github.com/kalidao/keep/actions/workflows/tests.yml) ![GitHub](https://img.shields.io/github/license/kalidao/keep) ![GitHub package.json version](https://img.shields.io/github/package-json/v/kalidao/keep) ![Solidity version](https://img.shields.io/badge/solidity-%3E%3D%200.8.17-lightgrey)

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
## Model

Keep is a governance system represented as an ERC1155 collection of NFTs. It includes multi-sig and DAO voting features. Keep NFTs are semi-fungible. This means in some cases, they represent 1:1 rights, such as multi-sig roles. Otherwise, they might be DAO voting balances or assets.

Keep is deployed to every chain at the following addresses:

`KeepFactory`: `0x00000000001cd071bd24a7561e642b3e121c9761`

`Keep`: `0x00000000058b15c4250af3e8a10a6cf2a0e0f1c4`

`URIfetcher`: `0xcCfC4897C01e3E0885AEe45643868276894c40eb`

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

## Learn more 

You can find the [docs](https://keep-kalico.vercel.app/) for Keep contracts here.

## License

[MIT](https://github.com/kalidao/keep/blob/main/LICENSE)
