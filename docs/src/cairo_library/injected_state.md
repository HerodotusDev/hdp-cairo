# Injected State API

Injected state provides a persistent key/value store backed by a Patricia trie. Use it when your computation needs state across runs.

## Methods

- `read_injected_state_trie_root(label)` -> `Option<felt252>`
- `read_key(label, key)` -> `Option<felt252>`
- `write_key(label, key, value)` -> updated trie root

Source: `hdp_cairo/src/injected_state/state.cairo`

## Example

```cairo
use hdp_cairo::HDP;
use hdp_cairo::injected_state::state::InjectedStateMemorizerTrait;

let label = 1;
let value = hdp.injected_state.read_key(label, 0x42);
```
