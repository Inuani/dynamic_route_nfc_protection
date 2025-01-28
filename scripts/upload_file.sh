#!/bin/bash
file=$1 
canister=${2:-smart_rap_cloth}
network=${3:-local}
contentType=$(file --mime-type -b "$file")
chunk_size=36000

byteArray=( $(od -An -v -tuC "$file") )
total_chunks=$(( (${#byteArray[@]} + chunk_size - 1) / chunk_size ))

i=0
chunk=1
while [ $i -lt ${#byteArray[@]} ]
do
   echo "Uploading chunk $chunk of $total_chunks"
   payload="vec {"
   for byte in "${byteArray[@]:$i:$chunk_size}"
   do
       payload+="$byte;"
   done
   payload+="}"
   dfx canister --network "$network" call "$canister" upload "$payload"
   i=$((i + chunk_size))
   chunk=$((chunk + 1))
done

dfx canister --network "$network" call "$canister" uploadFinalize "$contentType"