# Set the RPC environment variable

# eth_getBlockByNumber
curl -X POST \
  --url $RPC_URL \
  --header 'Content-Type: application/json' \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_getBlockByNumber",
    "params": ["0x5B8D80", false],
    "id": 1
  }'
