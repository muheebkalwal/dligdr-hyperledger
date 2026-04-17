# DLI-DGR: Distributed Ledger Infrastructure for Digital Government Resilience

## Overview
DLI-DGR is a consortium blockchain framework built on Hyperledger Fabric 2.5.0, designed to provide a shared coordination layer across separately governed government agencies. It addresses the cross-agency resilience gap in digital governments — specifically India's fragmented India Stack ecosystem (Aadhaar/UIDAI, UPI/NPCI, DigiLocker/MeitY).

## Problem It Solves
Current digital government infrastructure operates in silos. When one agency detects a threat or experiences a failure, other agencies have no automatic coordination mechanism. DLI-DGR provides a shared immutable ledger that all agencies read from and write to — enabling coordinated incident response without a central controller.

## Architecture
- **Network:** Hyperledger Fabric 2.5.0 with Raft consensus
- **Peers:** 2 peer nodes (Org1 — Identity Agency, Org2 — Payment Agency)
- **Channel:** mychannel
- **Consensus:** Raft (Crash Fault Tolerant)
- **Language:** Go (chaincode)

## Chaincode Functions

| Function | Description |
|---|---|
| `LogEvent` | Permanently records a government agency event on the shared ledger |
| `QueryEvent` | Retrieves a specific record by ID — any agency can query any record |
| `UpdateStatus` | Updates incident status from ACTIVE to RESOLVED |
| `GetAllRecords` | Returns complete transaction history across all agencies |
| `LogSensitiveEvent` | Routes sensitive identity data to Private Data Collections — only hash visible on shared ledger |

---

## Experimental Results

### Python Simulation (Google Colab)
| Experiment | Blocks | Result |
|---|---|---|
| Normal Operations | 6 | PASSED |
| Cross-Agency Incident Response | 4 | PASSED |
| Tamper Detection | 3 | TAMPERED — detected at Block 3 |
| System Failure and Recovery | 9 | PASSED |
| **Total** | **22** | **100% tamper detection** |

### Live Hyperledger Fabric Deployment
| Record | Agency | Event | Timestamp |
|---|---|---|---|
| REC001 | IDENTITY_AGENCY | FRAUD_DETECTED | 2026-04-11 08:55:19 |
| REC002 | PAYMENT_AGENCY | PAYMENT_FREEZE | 2026-04-11 08:56:08 |
| REC003 | DOCUMENT_AGENCY | DOCUMENT_REVOCATION | 2026-04-11 08:58:42 |
| REC004 | IDENTITY_AGENCY | ID_VERIFIED | 2026-04-11 08:59:42 |
| REC005 | PAYMENT_AGENCY | PAYMENT_PROCESSED | 2026-04-11 08:59:42 |
| REC006 | DOCUMENT_AGENCY | DOCUMENT_ISSUED | 2026-04-11 08:59:42 |

**Cross-agency fraud response time: 3 minutes 23 seconds across 3 agencies**

---

## Performance Benchmark

### Sequential Transaction Benchmark
Transactions submitted one at a time across batch sizes 20–200.

| Batch Size | Duration (s) | Throughput (TPS) | Latency (ms/tx) |
|---|---|---|---|
| 20 | 1.480 | 13.51 | 74.0 |
| 40 | 2.514 | 15.91 | 62.9 |
| 80 | 4.981 | 16.06 | 62.3 |
| 160 | 9.852 | 16.24 | 61.6 |
| 200 | 12.179 | 16.42 | 60.9 |

### Parallel Transaction Benchmark
Transactions submitted concurrently across batch sizes 20–200.

| Batch Size | Duration (s) | Throughput (TPS) | Latency (ms/tx) |
|---|---|---|---|
| 20 | 0.460 | 43.47 | 23.0 |
| 40 | 0.908 | 44.05 | 22.7 |
| 80 | 2.243 | 35.66 | 28.0 |
| 160 | 4.803 | 33.31 | 30.0 |
| 200 | 6.158 | 32.47 | 30.8 |

### Key Observations
- Sequential TPS stabilizes at ~16.4 TPS, demonstrating consistent and predictable throughput suitable for government incident logging
- Parallel execution peaks at 44 TPS at batch size 40, then degrades due to orderer contention — a known Hyperledger Fabric characteristic
- Parallel execution is up to 2.6x faster than sequential at small batch sizes
- Per-transaction latency remains under 75ms across all configurations — well within acceptable bounds for digital government systems
- All benchmarks achieved 100% transaction success rate

### Benchmark Environment
- Platform: macOS (Apple Silicon, Docker Desktop)
- Hyperledger Fabric: 2.5.0
- Hyperledger Fabric CA: 1.5.7
- Go: 1.20
- Docker: latest
- Network: 2-org Fabric test-network with Raft ordering

---

## Privacy Design
Sensitive identity data (Aadhaar biometrics) is never written to the shared channel. The `LogSensitiveEvent` function routes sensitive details to a Private Data Collection accessible only to authorised peers. Only non-sensitive metadata and a verification reference appear on the shared ledger — compliant with India's Digital Personal Data Protection Act 2023.

---

## Repository Structure

```
dligdr-hyperledger/
├── dligdr.go               # Main chaincode (Go)
├── go.mod                  # Go module definition
├── go.sum                  # Go dependency checksums
├── vendor/                 # Vendored Go dependencies
├── run_batch_test.sh       # Sequential transaction benchmark script
├── run_parallel_test.sh    # Parallel transaction benchmark script
├── results.csv             # Sequential benchmark results
├── results_parallel.csv    # Parallel benchmark results
└── README.md               # This file
```

---

## Setup Instructions

### Prerequisites
- Docker running
- Go 1.20+
- Hyperledger Fabric 2.5.0 binaries

### Steps

```bash
# Clone fabric-samples alongside this repo
git clone https://github.com/hyperledger/fabric-samples.git

# Install Fabric binaries
cd fabric-samples
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh
chmod +x install-fabric.sh
./install-fabric.sh --fabric-version 2.5.0 --ca-version 1.5.7 binary docker

# Set environment
export PATH=$PATH:$(pwd)/bin
export FABRIC_CFG_PATH=$(pwd)/config
export DOCKER_SOCK=/var/run/docker.sock  # adjust for your OS

# Start network
cd test-network
./network.sh up -ca
sleep 5

# Create channel manually if needed
scripts/createChannel.sh mychannel 3 5 false false

# Deploy DLI-DGR chaincode
./network.sh deployCC -c mychannel -ccn dligdr \
  -ccp /path/to/dligdr-hyperledger -ccl go

# Run sequential benchmark
bash /path/to/dligdr-hyperledger/run_batch_test.sh

# Run parallel benchmark
bash /path/to/dligdr-hyperledger/run_parallel_test.sh
```

---

## Citation
If you use this work, please cite our paper:

> DLI-DGR: A Distributed Ledger Infrastructure for Digital Government Resilience (under review)
