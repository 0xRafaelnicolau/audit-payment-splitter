## Audit Payment Splitter

**Allows payments to be split across multiple phases of an audit.** 

## Usage

### Build

```shell
$ forge build
```

### Setup RPC provider
```shell
$ ETH_RPC_URL="URL";
```

### Run tests
```shell
$ forge test --fork-url $ETH_RPC_URL
```

### TODO
* Generalize the provider role so that anyone can provide an audit.
* Think of a better way to divide payments accross different phases of an audit.
* Allow different phases to have different prices.