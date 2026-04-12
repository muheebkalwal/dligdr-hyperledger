# DLI-DGR: Distributed Ledger Infrastructure for Digital Government Resilience

## Overview
DLI-DGR is a consortium blockchain framework built on Hyperledger Fabric 2.5.0, designed to provide a shared coordination layer across separately governed government agencies. It addresses the cross-agency resilience gap in digital governments — specifically India's fragmented India Stack ecosystem (Aadhaar/UIDAI, UPI/NPCI, DigiLocker/MeitY).

## Problem It Solves
Current digital government infrastructure operates in silos. When one agency detects a threat or experiences a failure, other agencies have no automatic coordination mechanism. DLI-DGR provides a shared immutable ledger that all agencies read from and write to — enabling coordinated incident response without a central controller.

## Architecture
- **Network:** Hyperledger Fabric 2.5.0 with Raft consensus
- **Peers:** 2 peer nodes (Org1 — Identity Agency, Org2 — Payment Agency)
- **Channel:** dligdrchannel
- **Consensus:** Raft (Crash Fault Tolerant)
- **Language:** Go (chaincode), Python (simulation)

## Chaincode Functions

| Function | Description |
|---|---|
| LogEvent | Permanently records a government agency event on the shared ledger |
| QueryEvent | Retrieves a specific record by ID — any agency can query any record |
| UpdateStatus | Updates incident status from ACTIVE to RESOLVED |
| GetAllRecords | Returns complete transaction history across all agencies |
| LogSensitiveEvent | Routes sensitive identity data to Private Data Collections — only hash visible on shared ledger |

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

### Performance Benchmark (20 transactions)
| Metric | Value |
|---|---|
| Minimum latency | 63 ms |
| Maximum latency | 108 ms |
| Mean latency | 75.35 ms |
| Success rate | 100% |
| Environment | 2-node Hyperledger Fabric 2.5.0 |

## Privacy Design
Sensitive identity data (Aadhaar biometrics) is never written to the shared channel. The LogSensitiveEvent function routes sensitive details to a Private Data Collection accessible only to authorised peers. Only non-sensitive metadata and a verification reference appear on the shared ledger — compliant with India's Digital Personal Data Protection Act 2023.

## Deployment Environment
- Platform: GitHub Codespaces (Linux/amd64)
- Hyperledger Fabric: 2.5.0
- Hyperledger Fabric CA: 1.5.7
- Go: 1.20
- Docker: 28.5.1

## Setup Instructions

### Prerequisites
- Docker running
- Go 1.20+
- Hyperledger Fabric 2.5.0 binaries

### Steps
```bash
# Clone fabric-samples
git clone https://github.com/hyperledger/fabric-samples.git
cd fabric-samples

# Install Fabric binaries
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh
chmod +x install-fabric.sh
./install-fabric.sh --fabric-version 2.5.0 --ca-version 1.5.7 binary docker

# Set PATH
export PATH=$PATH:~/fabric-samples/bin
export FABRIC_CFG_PATH=~/fabric-samples/config

# Start network
cd test-network
./network.sh up createChannel -c dligdrchannel -ca

# Deploy DLI-DGR chaincode
./network.sh deployCC \
  -ccn dligdr \
  -ccp ~/dligdr-chaincode/go \
  -ccl go \
  -c dligdrchannel
