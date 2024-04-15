// Import ethers from ethers.js
import { ethers, utils } from 'ethers';

// // Placeholder private key (NEVER use hard-coded private keys in production)
const privateKey = '0x037420379234345678901234567890123456789012345678901d234567890123';
// const privateKey = '0x4646464646464646464646464646464646464646464646464646464646464646';

// // Set up a provider using the Rinkeby test network through Infura
const provider = new ethers.providers.JsonRpcProvider('https://mainnet.infura.io/v3/0b8f91c0ada04f51945d9a127629d2fb');

// The rest of your transaction signing and sending logic will go here

const wallet = new ethers.Wallet(privateKey, provider);

console.log("Wallet Address:", wallet.address);

async function signAndSerializeTransaction() {
  // Define the transaction object
  // const tx = {
  //   nonce: 5, // Nonce for the transaction
  //   gasLimit: ethers.utils.hexlify(21000), // Gas limit, 21000 is the base for an ETH transfer
  //   maxFeePerGas: 68033999199, // Current gas price
  //   maxPriorityFeePerGas: 36835938, // Current gas price
  //   to: "0x07d03A66c2fd7B9E60B4ae1177Ca439d967884bB", // Recipient address
  //   value: ethers.utils.parseEther("0.01"), // Amount to send
  //   data: "0x", // No additional data
  //   // chainId is very important for preventing replay attacks
  //   chainId: 1,
  //   type: 2
  // };

  const tx = {
    nonce: 3,
    gasLimit: ethers.utils.hexlify(21000), // Gas limit, 21000 is the base for an ETH transfer
    gasPrice: 1500000000, // Current gas price
    // maxPriorityFeePerGas: 36835938, // Current gas price
    to: "0xE919522e686D4e998e0434488273C7FA2ce153D8", // Recipient address
    value: 313999999999700, // Amount to send
    data: "0x", // No additional data
    // chainId is very important for preventing replay attacks
    // chainId: 1,
    type: 0
  };
  
  
  // Sign the transaction with the private key
  const signedTx = await wallet.signTransaction(tx);
  console.log("Signed Transaction:", signedTx);

  const response = await wallet.sendTransaction(tx);
  console.log('Transaction response:', response);

  // // Wait for the transaction to be mined
  const receipt = await response.wait();
  console.log('Transaction receipt:', receipt);

//   console.log("Signed Transaction:", signedTx);

  // You can now broadcast this signed transaction to the network:
  // const txResponse = await provider.sendTransaction(signedTx);
  // console.log("Transaction Hash:", txResponse.hash);
  // Note: Uncommenting the above lines will actually send the transaction to the network

  return signedTx;
}

function getRawTransaction(tx) {
  function addKey(accum, key) {
    if (tx[key]) { accum[key] = tx[key]; }
    return accum;
  }


  // Extract the relevant parts of the transaction and signature
  const txFields = "accessList chainId data gasPrice gasLimit maxFeePerGas maxPriorityFeePerGas nonce to type value".split(" ");
  const sigFields = "v r s".split(" ");

  // Seriailze the signed transaction
  const raw = utils.serializeTransaction(txFields.reduce(addKey, { }), sigFields.reduce(addKey, { }));

  // Double check things went well
  if (utils.keccak256(raw) !== tx.hash) { throw new Error("serializing failed!"); }

  return raw;
}

// Execute the function
signAndSerializeTransaction().catch(console.error);


// Wallet Address: 0xcfF5c79a7d95A83b47A0fdc2d6a9C2a3f48bca29
// Preimage: 0x82ff054dc8a0a01af799a385ab06cb3ef30a91f9c6dc6ce57e058e38daaaa84c
// Signed Transaction: 0xf8648085051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d864801ba04680d8aedaf30e0984a12e21e93d460370f6f08c94bf8575ec2f8b2733711ba6a06f5cbde850a26dadcf65571d954c72e80d9a38b4a703682269f3c8695b693d25
// Serialized: 0xe18085051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d86480
// Serialized: 0xe48085051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d86480018080
// Preimage: 0xa8843c24fb665475371a4b639fd88fda9d9ca8eb3400a41e57cc6059f696be5f
// Transaction response: {
//   nonce: 0,
//   gasPrice: BigNumber { _hex: '0x051f4d5c00', _isBigNumber: true },
//   gasLimit: BigNumber { _hex: '0x5208', _isBigNumber: true },
//   to: '0xE919522e686D4e998e0434488273C7FA2ce153D8',
//   value: BigNumber { _hex: '0x64', _isBigNumber: true },
//   data: '0x',
//   chainId: 1,
//   v: 38,
//   r: '0x36741622381074fde4db8ac42de9a0eca379e433bc0b51e605ff600cf0e62937',
//   s: '0x226b89ed569f3c508249154b3ca8ebe32c3239ff4a0beaa6c88e00290560b69a',
//   from: '0xcfF5c79a7d95A83b47A0fdc2d6a9C2a3f48bca29',
//   hash: '0x20243774ef0d0858d1b7c1ff215cbbba629239871434caf71bece2d27b8c7828',
//   type: null,
//   confirmations: 0,
//   wait: [Function (anonymous)]
// }
// Transaction receipt: {
//   to: '0xE919522e686D4e998e0434488273C7FA2ce153D8',
//   from: '0xcfF5c79a7d95A83b47A0fdc2d6a9C2a3f48bca29',
//   contractAddress: null,
//   transactionIndex: 17,
//   gasUsed: BigNumber { _hex: '0x5208', _isBigNumber: true },
//   logsBloom: '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
//   blockHash: '0xbeb766fd26083f550535e31885ae3e31164a2e6e43e2cee1229b2b6ced1478ed',
//   transactionHash: '0x20243774ef0d0858d1b7c1ff215cbbba629239871434caf71bece2d27b8c7828',
//   logs: [],
//   blockNumber: 19581433,
//   confirmations: 1,
//   cumulativeGasUsed: BigNumber { _hex: '0x15d333', _isBigNumber: true },
//   effectiveGasPrice: BigNumber { _hex: '0x051f4d5c00', _isBigNumber: true },
//   status: 1,
//   type: 0,
//   byzantium: true
// }

// node src/hdp/dev_utils/tx.js
// Wallet Address: 0xcfF5c79a7d95A83b47A0fdc2d6a9C2a3f48bca29
// Transaction: {
//   nonce: 2,
//   gasLimit: '0x5208',
//   gasPrice: 22000000000,
//   to: '0xE919522e686D4e998e0434488273C7FA2ce153D8',
//   value: 100,
//   data: '0x',
//   type: 0
// }
// chainId 0
// Serialized: 0xe10285051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d86480
// chainId 0
// digestToSign: 0xa421b8aa9ce2edd1e338e6cabd4117c41951a031df28a200554a5eb421e6df5f
// chainId 0
// Signature: {
//   r: '0x4a5712bfbf439a08c6a4be68d532364b2a7f952ab86f3d1f6702f5a6605f2f31',
//   s: '0x59544b1b86dfa7a4a11e7e34f1afd780a500106ee770f936ccff2e75edf0569d',
//   _vs: '0xd9544b1b86dfa7a4a11e7e34f1afd780a500106ee770f936ccff2e75edf0569d',
//   recoveryParam: 1,
//   v: 28,
//   yParityAndS: '0xd9544b1b86dfa7a4a11e7e34f1afd780a500106ee770f936ccff2e75edf0569d',
//   compact: '0x4a5712bfbf439a08c6a4be68d532364b2a7f952ab86f3d1f6702f5a6605f2f31d9544b1b86dfa7a4a11e7e34f1afd780a500106ee770f936ccff2e75edf0569d'
// }
// chainId 0
// Signed Transaction: 0xf8640285051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d864801ca04a5712bfbf439a08c6a4be68d532364b2a7f952ab86f3d1f6702f5a6605f2f31a059544b1b86dfa7a4a11e7e34f1afd780a500106ee770f936ccff2e75edf0569d
// Transaction: {
//   nonce: 2,
//   gasLimit: '0x5208',
//   gasPrice: 22000000000,
//   to: '0xE919522e686D4e998e0434488273C7FA2ce153D8',
//   value: 100,
//   data: '0x',
//   type: 0,
//   chainId: 1
// }
// chainId 1
// Serialized: 0xe40285051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d86480018080
// chainId 1
// digestToSign: 0xc4683c1a7601bf1b177b0f26725dd187a6030e8e5dae4dc632dabf9707a0f7e6
// chainId 1
// Signature: {
//   r: '0xe0e710bebe2e0e90b9a40aff9f2d60c2dda1511903d7c5b2873aa9cf47345fda',
//   s: '0x7fd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26',
//   _vs: '0xffd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26',
//   recoveryParam: 1,
//   v: 28,
//   yParityAndS: '0xffd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26',
//   compact: '0xe0e710bebe2e0e90b9a40aff9f2d60c2dda1511903d7c5b2873aa9cf47345fdaffd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26'
// }
// chainId 1
// Transaction response: {
//   nonce: 2,
//   gasPrice: BigNumber { _hex: '0x051f4d5c00', _isBigNumber: true },
//   gasLimit: BigNumber { _hex: '0x5208', _isBigNumber: true },
//   to: '0xE919522e686D4e998e0434488273C7FA2ce153D8',
//   value: BigNumber { _hex: '0x64', _isBigNumber: true },
//   data: '0x',
//   chainId: 1,
//   v: 38,
//   r: ' ',
//   s: '0x7fd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26',
//   from: '0xcfF5c79a7d95A83b47A0fdc2d6a9C2a3f48bca29',
//   hash: '0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51',
//   type: null,
//   confirmations: 0,
//   wait: [Function (anonymous)]
// }


0x26a0e0e710bebe2e0e90b9a40aff9f2d60c2dda1511903d7c5b2873aa9cf47345fdaa07fd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26


// 0xf8640285051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d8648026a0e0e710bebe2e0e90b9a40aff9f2d60c2dda1511903d7c5b2873aa9cf47345fda7fd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26