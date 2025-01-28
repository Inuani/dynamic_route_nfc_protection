#!/bin/bash
canister=${2:-smart_rap_cloth}
network=${3:-local}

# Get file from canister
response=$(dfx canister --network "$network" call "$canister" getFile)

# Extract content type and derive extension
content_type=$(echo "$response" | sed -n 's/.*contentType = "\([^"]*\)".*/\1/p')
ext=$(echo "$content_type" | sed -n 's/.*\/\([^"]*\).*/\1/p')
output_file="${1:-downloaded.$ext}"

# Extract and process blob data
echo "$response" | 
  sed -n 's/.*blob "\([^"]*\)".*/\1/p' |
  xxd -r -p > "$output_file" 2>/dev/null

echo "Downloaded $(wc -c < "$output_file") bytes as $content_type"