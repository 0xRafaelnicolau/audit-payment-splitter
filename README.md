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
* Have a different role for the admin and for different team proposer.
* Create an allowlist of tokens.