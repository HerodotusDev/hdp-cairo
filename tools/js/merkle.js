import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { create } from "domain";
import fs from "fs";

function createMerkleTreeValues() {
  const values = [
    ["0x0000000000000000000000000000000000000000000000000000000000000001"],
    ["0x0000000000000000000000000000000000000000000000000000000000000002"],
    ["0x000000000000000000000000000000000000000000000000000000000000007a"],
    ["0x0000000000000000000000000000000000000000000000000000000000000004"],
    ["0x0000000000000000000000000000000000000000000000000000000000000001"],
  ];

  let roots = [];
  for(let i = 0; i < values.length; i++) {
    const subset = values.slice(0, i + 1);
    const tree = StandardMerkleTree.of(subset, ["bytes32"], {sortLeaves: false});
    roots.push(tree.root);
  }

  console.log(roots);
}

// createMerkleTreeValues();