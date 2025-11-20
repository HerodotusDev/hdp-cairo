#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <api_key>"
    exit 1
fi

API_KEY="$1"
DESTINATION_CHAIN_ID="0x534e5f4d41494e" # Starknet Mainnet

# 1) First request - create Atlantic query and capture response
ATLANTIC_RESPONSE=$(
  curl -s --request POST \
    --url "https://atlantic.api.herodotus.cloud/atlantic-query?apiKey=${API_KEY}" \
    --header 'Content-Type: multipart/form-data' \
    --form sharpProver=stone \
    --form layout=auto \
    --form result=PROOF_VERIFICATION_ON_L2 \
    --form mockFactHash=false \
    --form network=MAINNET \
    --form declaredJobSize=M \
    --form "pieFile=@./pie.zip;type=application/zip"
)

echo "Atlantic response: $ATLANTIC_RESPONSE"

# 2) Extract atlanticQueryId from response JSON: { "atlanticQueryId": "string" }
ATLANTIC_QUERY_ID=$(echo "$ATLANTIC_RESPONSE" | jq -r '.atlanticQueryId')

if [ -z "$ATLANTIC_QUERY_ID" ] || [ "$ATLANTIC_QUERY_ID" = "null" ]; then
    echo "Failed to extract atlanticQueryId from response"
    exit 1
fi

echo "Using atlanticQueryId: $ATLANTIC_QUERY_ID"

# 3) Second request - send atlantic_query_id to HDP server
curl -v -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: ${API_KEY}" \
  -d "{
    \"destination_chain_id\": \"${DESTINATION_CHAIN_ID}\",
    \"atlantic_query_id\": \"${ATLANTIC_QUERY_ID}\"
  }" \
  "${HDP_SERVER_URL}/tasks/decommitment"
