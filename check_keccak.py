
import sys

print("Checking eth_hash...")
try:
    from eth_hash.auto import keccak
    print(f"eth_hash.auto working: {keccak(b'').hex()}")
except Exception as e:
    print(f"eth_hash.auto failed: {e}")

print("\nChecking starkware libs...")
try:
    from starkware.starknet.public.abi import starknet_keccak
    print("starknet_keccak imported")
except ImportError:
    print("starknet_keccak failed")

try:
    from starkware.eth.utils import keccak
    print(f"starkware.eth.utils.keccak working: {keccak(b'').hex()}")
except ImportError:
    print("starkware.eth.utils failed to import")
except Exception as e:
    print(f"starkware.eth.utils.keccak failed: {e}")

try:
    import Crypto.Hash.Keccak
    print("Crypto.Hash.Keccak imported")
except ImportError:
    print("Crypto.Hash.Keccak failed")
