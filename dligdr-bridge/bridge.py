import subprocess
import time
import hashlib
import secrets
import json

# --- ZKP UTILS ---
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFF
G = 2

def generate_schnorr_proof(secret_id):
    x = int(hashlib.sha256(secret_id.encode()).hexdigest(), 16) % P
    y = pow(G, x, P)
    r = secrets.randbelow(P)
    C = pow(G, r, P)
    e = int(hashlib.sha256(f"{G}{y}{C}".encode()).hexdigest(), 16) % P
    s = (r + e * x) % (P - 1)
    return {"y": str(y), "C": str(C), "s": str(s)}

# --- FABRIC INVOKE LOGIC ---
def invoke_fabric_event(agency, event_type, secret_data):
    proof = generate_schnorr_proof(secret_data)
    record_id = f"REC_{int(time.time())}"
    
    # 6 Arguments for LogSecuredEvent
    args = [record_id, agency, event_type, proof['y'], proof['C'], proof['s']]
    
    # Create the JSON string properly
    ctor_dict = {"function": "LogSecuredEvent", "Args": args}
    ctor_json = json.dumps(ctor_dict)
    
    # Absolute Paths for Muheeb's Environment
    base_path = "/Users/muheeb_kalwal/Desktop/Blockchain/fabric-samples/test-network/organizations"
    
    # Building the command using the clean JSON string
    cmd = (
        f'peer chaincode invoke -o localhost:7050 '
        f'--ordererTLSHostnameOverride orderer.example.com --tls '
        f'--cafile "{base_path}/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" '
        f'-C mychannel -n dligdr '
        f'--peerAddresses localhost:7051 --tlsRootCertFiles "{base_path}/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" '
        f'--peerAddresses localhost:9051 --tlsRootCertFiles "{base_path}/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" '
        f"-c '{ctor_json}'"
    )

    print(f"\n[DLI-DGR] Proving Incident via ZKP for {agency}...")
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[SUCCESS] ZKP Verified. Block Committed. ID: {record_id}")
            return True
        else:
            print(f"[ERROR] Transaction Rejected: {result.stderr}")
            return False
    except Exception as e:
        print(f"[CRITICAL] Error: {str(e)}")
        return False

if __name__ == "__main__":
    invoke_fabric_event("IDENTITY_AGENCY", "FRAUD_DETECTED", "PRIVATE_BIO_REF_99")