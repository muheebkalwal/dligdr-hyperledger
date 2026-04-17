#!/bin/bash

cd /Users/muheeb_kalwal/Desktop/Blockchain/fabric-samples/test-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

echo "batch_size,duration_seconds,tps" > ~/Desktop/Blockchain/results_parallel.csv

for BATCH in 20 40 80 160 200; do
    echo "Running $BATCH parallel transactions..."
    START=$(date +%s%N)
    for i in $(seq 1 $BATCH); do
        peer chaincode invoke \
            -o localhost:7050 \
            --ordererTLSHostnameOverride orderer.example.com \
            --tls --cafile $ORDERER_CA \
            -C mychannel -n dligdr \
            --peerAddresses localhost:7051 \
            --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
            -c "{\"function\":\"LogEvent\",\"Args\":[\"PAR${BATCH}_${i}\",\"AgencyB\",\"INCIDENT\",\"Parallel event $i\"]}" \
            > /dev/null 2>&1 &
    done
    wait
    END=$(date +%s%N)
    DURATION=$(echo "scale=3; ($END - $START) / 1000000000" | bc)
    TPS=$(echo "scale=2; $BATCH / $DURATION" | bc)
    echo "$BATCH,$DURATION,$TPS" >> ~/Desktop/Blockchain/results_parallel.csv
    echo "Batch $BATCH done: ${DURATION}s, TPS: $TPS"
done

echo "Done! Results saved to ~/Desktop/Blockchain/results_parallel.csv"
