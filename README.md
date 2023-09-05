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
* Use access control instead of ownable
* Think of a better way to divide payments accross different phases in regards to indexes.
* Allow different phases to have different prices.