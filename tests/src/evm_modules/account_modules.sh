# Set the RPC environment variable

# eth_getTransactionCount
curl -X POST \
  --url $RPC_URL \
  --header 'Content-Type: application/json' \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_getTransactionCount",
    "params": ["0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97", "0x756038"],
    "id": 1
  }'

# eth_getBalance
curl -X POST \
  --url $RPC_URL \
  --header 'Content-Type: application/json' \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_getBalance",
    "params": ["0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97", "0x756038"],
    "id": 1
  }'

# eth_getProof
curl -X POST \
  --url $RPC_URL \
  --header 'Content-Type: application/json' \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_getProof",
    "params": ["0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97", [], "0x756038"],
    "id": 1
  }'
