# Dry vs Sound Handlers

Dry run and sound run execute the same Cairo code, but their syscall handlers behave differently.

| Aspect | Dry Run | Sound Run |
| --- | --- | --- |
| Network access | Yes (RPC calls) | No (offline) |
| Determinism | No (live data) | Yes |
| Purpose | Discover keys | Execute with proofs |
| State source | RPC + key collection | Memorizers |
| Handler crate | `dry_hint_processor` | `sound_hint_processor` |

## Example behavior (header fetch)

Dry run:

```
fetch header via RPC
insert DryRunKey::Header
return decoded header fields
```

Sound run:

```
read header bytes from memorizer
decode RLP
return header fields
```

The interface presented to Cairo remains the same in both modes.
