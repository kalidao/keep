<img align="right" width="150" height="150" top="0" src="./assets/KALI_K.jpg">

# multi-sig • [![tests](https://github.com/kalidao/multi-sig/actions/workflows/tests.yml/badge.svg)](https://github.com/kalidao/multi-sig/actions/workflows/tests.yml) ![GitHub](https://img.shields.io/github/license/kalidao/multi-sig)  ![GitHub package.json version](https://img.shields.io/github/package-json/v/kalidao/multi-sig)

EIP-712 multi-sig with ERC-1155 for signers.

## Blueprint

```ml
lib
├─ ds-test — https://github.com/dapphub/ds-test
├─ forge-std — https://github.com/brockelmore/forge-std
src
├─ tests
│  └─ ...
├─ ERC1155votes — "Minimalist and gas efficient standard ERC-1155 implementation with Compound-like voting"
├─ KaliClub — "EIP-712 multi-sig with ERC-1155 for signers"
└─ KaliClubFactory — "Kali Club Factory"
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

[AGPL-3.0-only](https://github.com/abigger87/femplate/blob/master/LICENSE)
