"""
Merkle Mountain Range
Adapted from https://github.com/jjyr/mmr.py (MIT License)
Replicates the MMR behavior of the chunk processor, ie : 
    - the leafs are directly inserted in the tree without any hashing (they're supposed to be already hashes of block headers)
    - merging is done by hashing the two hashes together, without prepending any indexes
    - the root is computed by bagging the peaks and hashing the result with the size of the MMR
"""

from typing import List, Tuple, Union
import sha3
from starkware.cairo.common.poseidon_hash import (
    poseidon_hash,
    poseidon_hash_single,
    poseidon_hash_many,
)


class PoseidonHasher:
    def __init__(self):
        self.items = []

    def update(self, item: Union[int, bytes]):
        if isinstance(item, int):
            self.items.append(item)
        elif isinstance(item, bytes):
            self.items.append(int.from_bytes(item, "big"))
        else:
            raise TypeError(f"Unsupported type: {type(item)}, {item}")

    def digest(self) -> int:
        num_items = len(self.items)

        if num_items == 1:
            result = poseidon_hash_single(self.items[0])
        elif num_items == 2:
            result = poseidon_hash(self.items[0], self.items[1])
        elif num_items > 2:
            result = poseidon_hash_many(self.items)
        else:
            raise ValueError("No item to digest")

        self.items.clear()
        return result


class KeccakHasher:
    def __init__(self):
        self.keccak = sha3.keccak_256()

    def update(self, item: Union[int, bytes]):
        if isinstance(item, int):
            self.keccak.update(item.to_bytes(32, "big"))
        elif isinstance(item, bytes):
            self.keccak.update(item)
        else:
            raise TypeError(f"Unsupported type: {type(item)}, {item}")

    def digest(self) -> int:
        result = int.from_bytes(self.keccak.digest(), "big")
        self.keccak = sha3.keccak_256()
        return result


class MockedHasher:
    def __init__(self):
        self.hash_count = 0

    def update(self, _):
        pass

    def digest(self) -> int:
        self.hash_count += 1
        return 0


def is_valid_mmr_size(n):
    prev_peak = 0
    while n > 0:
        i = n.bit_length()
        peak = 2**i - 1
        if peak > n:
            i -= 1
            peak = 2**i - 1
        if peak == prev_peak:
            return False
        prev_peak = peak
        n -= peak
    return n == 0


def tree_pos_height(pos: int) -> int:
    """
    calculate pos height in tree
    Explains:
    https://github.com/mimblewimble/grin/blob/0ff6763ee64e5a14e70ddd4642b99789a1648a32/core/src/core/pmmr.rs#L606
    use binary expression to find tree height(all one position number)
    return pos height
    """
    # convert from 0-based to 1-based position, see document
    pos += 1
    bit_length = pos.bit_length()
    while not (1 << bit_length) - 1 == pos:
        most_significant_bits = 1 << bit_length - 1
        pos -= most_significant_bits - 1
        bit_length = pos.bit_length()

    return bit_length - 1


# get left or right sibling offset by height
def sibling_offset(height) -> int:
    return (2 << height) - 1


def get_peaks(mmr_size) -> List[int]:
    """
    return peaks positions from left to right, 0-index based.
    """

    def get_right_peak(height, pos, mmr_size):
        """
        find next right peak
        peak not exsits if height is -1
        """
        # jump to right sibling
        pos += sibling_offset(height)
        # jump to left child
        while pos > mmr_size - 1:
            height -= 1
            if height < 0:
                # no right peak exists
                return (height, None)
            pos -= 2 << height
        return (height, pos)

    poss = []
    height, pos = left_peak_height_pos(mmr_size)
    poss.append(pos)
    while height > 0:
        height, pos = get_right_peak(height, pos, mmr_size)
        if height >= 0:
            poss.append(pos)
    return poss


def left_peak_height_pos(mmr_size: int) -> Tuple[int, int]:
    """
    find left peak
    return (left peak height, pos)
    """

    def get_left_pos(height):
        """
        convert height to binary express, then minus 1 to get 0 based pos
        explain:
        https://github.com/mimblewimble/grin/blob/master/doc/mmr.md#structure
        https://github.com/mimblewimble/grin/blob/0ff6763ee64e5a14e70ddd4642b99789a1648a32/core/src/core/pmmr.rs#L606
        For example:
        height = 2
        # use one-based encoding, mean that left node is all one-bits
        # 0b1 is 0 pos, 0b11 is 2 pos 0b111 is 6 pos
        one_based_binary_encoding = 0b111
        pos = 0b111 - 1 = 6
        """
        return (1 << height + 1) - 2

    height = 0
    prev_pos = 0
    pos = get_left_pos(height)
    # increase height and get most left pos of tree
    # once pos is out of mmr_size we consider previous pos is left peak
    while pos < mmr_size:
        height += 1
        prev_pos = pos
        pos = get_left_pos(height)
    return (height - 1, prev_pos)


class MMR(object):
    """
    MMR
    """

    def __init__(
        self,
        hasher: Union[PoseidonHasher, KeccakHasher, MockedHasher] = PoseidonHasher(),
    ):
        self.last_pos = -1
        self.pos_hash = {}
        self._hasher = hasher

    def add(self, elem: Union[bytes, int]) -> int:
        """
        Insert a new leaf, v is a binary value
        """
        self.last_pos += 1

        # store hash
        self.pos_hash[self.last_pos] = elem
        height = 0
        pos = self.last_pos
        # merge same sub trees
        # if next pos height is higher implies we are in right children
        # and sub trees can be merge
        while tree_pos_height(self.last_pos + 1) > height:
            # increase pos cursor
            self.last_pos += 1
            # calculate pos of left child and right child
            left_pos = self.last_pos - (2 << height)
            right_pos = left_pos + sibling_offset(height)
            # calculate parent hash
            self._hasher.update(self.pos_hash[left_pos])
            self._hasher.update(self.pos_hash[right_pos])
            self.pos_hash[self.last_pos] = self._hasher.digest()
            height += 1
        return pos

    def get_root(self) -> int:
        """
        MMR root
        """
        peaks = get_peaks(self.last_pos + 1)
        peaks_values = [self.pos_hash[p] for p in peaks]
        bagged = self.bag_peaks(peaks_values)
        self._hasher.update(self.last_pos + 1)
        self._hasher.update(bagged)
        root = self._hasher.digest()
        return root

    def get_peaks(self) -> list:
        peaks = get_peaks(self.last_pos + 1)
        peaks_values = [self.pos_hash[p] for p in peaks]

        return peaks_values

    def bag_peaks(self, peaks: List[int]) -> int:
        bags = peaks[-1]
        for peak in reversed(peaks[:-1]):
            self._hasher.update(peak)
            self._hasher.update(bags)

            bags = self._hasher.digest()

        return bags

    def gen_proof(self, pos: int) -> "MerkleProof":
        """
        generate a merkle proof
        1. generate merkle tree proof for pos
        2. find peaks positions
        3. find rhs peaks packs into one single hash, then push to proof
        4. find lhs peaks reverse then push to proof

        For peaks: P1, P2, P3, P4, P5, we proof a P4 leaf
        [P4 merkle proof.., P5, P3, P2, P1]
        """
        proof = []
        height = tree_pos_height(pos)
        assert height == 0, f"Forbidden to prove non-leaf element"
        # construct merkle proof of one peak
        while pos <= self.last_pos:
            # print(f"Pos:{pos}, height:{height}")
            pos_height = tree_pos_height(pos)
            next_height = tree_pos_height(pos + 1)
            if next_height > pos_height:
                # get left child sib
                sib = pos - sibling_offset(height)
                # print(
                #     f"Sib:{sib}, pos:{pos}, offset : {sibling_offset(height)}, heigh:{height}"
                # )
                # break if sib is out of mmr
                if sib > self.last_pos:
                    break
                proof.append(self.pos_hash[sib])
                # print(f"Proof: {proof}")
                # goto parent node
                pos += 1
            else:
                # get right child
                sib = pos + sibling_offset(height)
                # break if sib is out of mmr
                if sib > self.last_pos:
                    break
                proof.append(self.pos_hash[sib])
                # print(f"Proof: {proof}")
                # goto parent node
                pos += 2 << height
            height += 1
        # now pos is peak of the mountain(because pos can't find a sibling)
        peak_pos = pos
        peaks = get_peaks(self.last_pos + 1)
        # bagging rhs peaks into one hash
        rhs_peak_hash = self._bag_rhs_peaks(peak_pos, peaks)
        if rhs_peak_hash is not None:
            proof.append(rhs_peak_hash)
            # f"Proof RHS: {proof}")
        # insert lhs peaks
        proof.extend(reversed(self._lhs_peaks(peak_pos, peaks)))
        # f"Proof LHS: {proof}")
        return MerkleProof(mmr_size=self.last_pos + 1, proof=proof, hasher=self._hasher)

    def _bag_rhs_peaks(self, peak_pos: int, peaks: List[int]):
        rhs_peak_hashes = [self.pos_hash[p] for p in peaks if p > peak_pos]
        # print(f"RHS: {rhs_peak_hashes}")
        if len(rhs_peak_hashes) == 0:
            return None
        if len(rhs_peak_hashes) == 1:
            return rhs_peak_hashes[0]
        if len(rhs_peak_hashes) >= 2:
            bags = rhs_peak_hashes[-1]
            # print(f"init bags: {bags}")
            for peak in reversed(rhs_peak_hashes[:-1]):
                # print(f"Hashing: {peak}, {bags}")
                self._hasher.update(peak)
                self._hasher.update(bags)

                bags = self._hasher.digest()

        return bags

    def _lhs_peaks(self, peak_pos: int, peaks: List[int]) -> List[bytes]:
        return [self.pos_hash[p] for p in peaks if p < peak_pos]


class MerkleProof(object):
    """
    MerkleProof, used for verify a proof
    """

    def __init__(self, mmr_size: int, proof: List[bytes], hasher):
        self.mmr_size = mmr_size
        self.proof = proof
        self._hasher = hasher

    def __repr__(self) -> str:
        return f"mmr size {self.mmr_size}, proof:{self.proof}"

    def verify(self, root: bytes, pos: int, elem: bytes) -> bool:
        """
        verify proof
        root - MMR root that generate this proof
        pos - elem insertion pos
        elem - elem
        """
        # print(f"Verifying proof: {self}")
        peaks = get_peaks(self.mmr_size)
        # print(f"Pos: {pos}, peaks: {peaks}")
        elem_hash = elem
        height = 0
        for proof in self.proof:
            hasher = self._hasher
            # verify bagging peaks
            if pos in peaks:
                # print(f"Pos in peaks: {pos}")

                if pos == peaks[-1]:
                    hasher.update(proof)
                    hasher.update(elem_hash)
                    # print(f"Hashing : {proof}, {elem_hash}")
                else:
                    hasher.update(elem_hash)
                    hasher.update(proof)
                    # print(f"Hashing : {elem_hash}, {proof}")
                    pos = peaks[-1]
                elem_hash = hasher.digest()
                # print(f"Hash result : {elem_hash}")
                continue

            # verify merkle path
            pos_height = tree_pos_height(pos)
            next_height = tree_pos_height(pos + 1)
            if next_height > pos_height:
                # we are in right child
                hasher.update(proof)
                hasher.update(elem_hash)
                pos += 1
            else:
                # we are in left child
                hasher.update(elem_hash)
                hasher.update(proof)
                pos += 2 << height
            # print(f"MerklePath: elem:{elem_hash}, proof:{proof}")
            elem_hash = hasher.digest()
            height += 1
        hasher = self._hasher
        hasher.update(self.mmr_size)
        hasher.update(elem_hash)
        expected_root = hasher.digest()
        assert expected_root == root, f"Expected root: {expected_root}, got: {root}"


if __name__ == "__main__":
    poseidon_mmr = MMR(PoseidonHasher())
    for i in range(11):
        _ = poseidon_mmr.add(i)

    print(poseidon_mmr.get_root())
    print(f"MMr len : {poseidon_mmr.last_pos+1}")
    print(f"MMR: {poseidon_mmr.pos_hash}")
    proof_pos = 1
    x = poseidon_mmr.gen_proof(proof_pos)
    print(x)
    print(
        x.verify(poseidon_mmr.get_root(), proof_pos, poseidon_mmr.pos_hash[proof_pos])
    )
    # keccak_mmr = MMR(KeccakHasher())
    # for i in range(3):
    #     _ = keccak_mmr.add(i)
    # print(keccak_mmr.get_root())
