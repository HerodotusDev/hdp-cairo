# Set the RPC environment variable

# eth_getStorageAt
curl -X POST \
  --url $RPC_URL \
  --header 'Content-Type: application/json' \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_getStorageAt",
    "params": [
        "0x75cec1db9dceb703200eaa6595f66885c962b920", 
        "0x1", 
        "0x756038"
    ],
    "id": 1
  }'
