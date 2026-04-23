#!/bin/zsh

export PATH=/Users/muheeb_kalwal/fabric-samples/bin:$PATH
export FABRIC_CFG_PATH=/Users/muheeb_kalwal/fabric-samples/config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/Users/muheeb_kalwal/fabric-samples/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/Users/muheeb_kalwal/fabric-samples/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

ORDERER_CA="/Users/muheeb_kalwal/fabric-samples/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
PEER1_TLS="/Users/muheeb_kalwal/fabric-samples/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
PEER2_TLS="/Users/muheeb_kalwal/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
PEER_BIN="/Users/muheeb_kalwal/fabric-samples/bin/peer"

CSV_FILE="/Users/muheeb_kalwal/dligdr-benchmark-results.csv"
COOLDOWN=5
ID_OFFSET=10000

ROUNDS=(20 40 80 160 320 640 1280 2000)
AGENCIES=("CERT-IN" "NIC" "MHA" "MoD" "UIDAI" "RBI" "NCIIPC" "DoT")
EVENT_TYPES=("FRAUD_ALERT" "BREACH" "DDOS" "PHISHING" "RANSOMWARE" "INTRUSION" "DATA_LEAK" "APT")

echo "Round,BatchSize,Success,Failure,ElapsedSec,TPS" > "${CSV_FILE}"

run_round() {
    local round_num=$1
    local batch_size=$2
    local id_start=$3

    echo ""
    echo "========================================"
    echo "ROUND ${round_num}: ${batch_size} transactions"
    echo "========================================"

    local success=0
    local failure=0
    local tx_index=0

    local round_start
    round_start=$(python3 -c "import time; print(time.time())")

    while [ ${tx_index} -lt ${batch_size} ]; do
        tx_index=$(( tx_index + 1 ))

        local global_id=$(( id_start + tx_index ))
        local agency_index=$(( tx_index % 8 ))
        local event_index=$(( (tx_index * 3) % 8 ))
        local record_id="REC$(printf '%07d' ${global_id})"
        local agency="${AGENCIES[${agency_index}]}"
        local event_type="${EVENT_TYPES[${event_index}]}"
        local details="Incident_${global_id}_benchmark"

        ${PEER_BIN} chaincode invoke \
            -o localhost:7050 \
            --ordererTLSHostnameOverride orderer.example.com \
            --tls \
            --cafile "${ORDERER_CA}" \
            -C mychannel \
            -n dligdr \
            --peerAddresses localhost:7051 \
            --tlsRootCertFiles "${PEER1_TLS}" \
            --peerAddresses localhost:9051 \
            --tlsRootCertFiles "${PEER2_TLS}" \
            -c "{\"function\":\"LogEvent\",\"Args\":[\"${record_id}\",\"${agency}\",\"${event_type}\",\"${details}\"]}" \
            2>/dev/null 1>/dev/null

        if [ $? -eq 0 ]; then
            success=$(( success + 1 ))
        else
            failure=$(( failure + 1 ))
        fi

        if [ $(( tx_index % 50 )) -eq 0 ]; then
            echo "  Progress: ${tx_index}/${batch_size} (success: ${success}, failure: ${failure})"
        fi
    done

    local round_end
    round_end=$(python3 -c "import time; print(time.time())")
    local elapsed
    elapsed=$(python3 -c "print(round(${round_end} - ${round_start}, 3))")

    local tps=0
    if [ ${success} -gt 0 ]; then
        tps=$(python3 -c "print(round(${success} / ${elapsed}, 2))")
    fi

    echo ""
    echo "  BatchSize  : ${batch_size}"
    echo "  Success    : ${success}"
    echo "  Failure    : ${failure}"
    echo "  ElapsedSec : ${elapsed}"
    echo "  TPS        : ${tps}"

    echo "${round_num},${batch_size},${success},${failure},${elapsed},${tps}" >> "${CSV_FILE}"
}

echo ""
echo "DLI-DGR Hyperledger Fabric Benchmark"
echo "Started: $(date)"
echo "Rounds  : ${ROUNDS[*]}"
echo "Output  : ${CSV_FILE}"
echo ""

round_num=0
cumulative=0
for batch_size in "${ROUNDS[@]}"; do
    round_num=$(( round_num + 1 ))
    id_start=$(( ID_OFFSET + cumulative ))
    run_round ${round_num} ${batch_size} ${id_start}
    cumulative=$(( cumulative + batch_size ))
    if [ ${round_num} -lt ${#ROUNDS[@]} ]; then
        echo ""
        echo "  Cooldown: ${COOLDOWN}s before next round..."
        sleep ${COOLDOWN}
    fi
done

echo ""
echo "========================================"
echo "BENCHMARK COMPLETE"
echo "Finished: $(date)"
echo "Results saved to: ${CSV_FILE}"
echo "========================================"
echo ""
echo "Results preview:"
cat "${CSV_FILE}"
