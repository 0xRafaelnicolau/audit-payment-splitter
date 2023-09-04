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

## TODO

* Generalize the provider role so anyone can use the protocol.
* Process the first payment upon agreement.
* Let the client reject the provider offer.
