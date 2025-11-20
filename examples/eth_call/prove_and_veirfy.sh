#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <api_key>"
    exit 1
fi

curl --request POST \
    --url https://atlantic.api.herodotus.cloud/atlantic-query?apiKey=$1 \
    --header 'Content-Type: multipart/form-data' \
    --form sharpProver=stone \
    --form layout=auto \
    --form result=PROOF_VERIFICATION_ON_L2 \
    --form mockFactHash=true \
    --form network=TESTNET \
    --form declaredJobSize=M \
    --form "pieFile=@./pie.zip;type=application/zip"


ATLANTIC_QUERY_ID="01KA757C4HW3XQTJXE35H61A4E"
PROGRAM_HASH="0x34a16478e83f69c4f0bcdb7549d32f92c9b7776bb3f71da06de334f1871eba0"


curl -v -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: ${API_KEY}" \
  -d "{
    \"destination_chain_id\": \"${DESTINATION_CHAIN_ID}\",
    \"atlantic_query_id\": \"${ATLANTIC_QUERY_ID}\"
  }" \
  "${HDP_SERVER_URL}/tasks/decommitment"