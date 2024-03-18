# Cairo HDP

![](.github/offchain-evm.png)

---

This repository implements the logic of HDP in Cairo. HDP enables verifiedable computations on On-chain Ethereum data.

Visualization of an MMR
![merkle mountain range tree](.github/mmr.png)

## Setup

### Create a virtual environment and install the dependencies (one-time setup)

```bash
make setup
```

After that and every time you get back to the repo, you will need to activate the virtual environment by doing:

```bash
source venv/bin/activate
```

### Run Cairo unit tests

```bash
make test-hdp
```

Herodotus Dev Ltd - 2024.
