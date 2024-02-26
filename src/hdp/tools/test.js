import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// // (1)
// const values = ["e7e68b55673df272494194c9d0e150fb5486e146c13a312bd1d83c1388d73c59"];

// // (2)
// const tree = StandardMerkleTree.of(values, "bytes32");

// // (3)
// console.log('Merkle Root:', tree.root);

// // (4)
// fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));


// (1)
const values = [
  ["0xe7e68b55673df272494194c9d0e150fb5486e146c13a312bd1d83c1388d73c59"],
];

// (2)
const tree = StandardMerkleTree.of(values, ["bytes32"]);

// (3)
console.log('Merkle Root:', tree.root);

// (4)
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));