import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
const values = [
  ["0x46296bc9cb11408bfa46c5c31a542f12242db2412ee2217b4e8add2bc1927d0b"],
];

// (2)
const tree = StandardMerkleTree.of(values, ["bytes32"]);

// (3)
console.log('Merkle Root:', tree.root);

// (4)
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));