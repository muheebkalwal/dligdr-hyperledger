package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type IncidentRecord struct {
	RecordID  string `json:"record_id"`
	Agency    string `json:"agency"`
	EventType string `json:"event_type"`
	Details   string `json:"details"`
	Timestamp string `json:"timestamp"`
	Status    string `json:"status"`
}

type DLIGDRContract struct {
	contractapi.Contract
}

func (c *DLIGDRContract) LogEvent(ctx contractapi.TransactionContextInterface,
	recordID string, agency string, eventType string, details string) error {

	existing, err := ctx.GetStub().GetState(recordID)
	if err != nil {
		return fmt.Errorf("failed to read ledger: %v", err)
	}
	if existing != nil {
		return fmt.Errorf("record %s already exists", recordID)
	}

	record := IncidentRecord{
		RecordID:  recordID,
		Agency:    agency,
		EventType: eventType,
		Details:   details,
		Timestamp: time.Now().Format("2006-01-02 15:04:05"),
		Status:    "ACTIVE",
	}

	recordJSON, err := json.Marshal(record)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(recordID, recordJSON)
}

func (c *DLIGDRContract) QueryEvent(ctx contractapi.TransactionContextInterface,
	recordID string) (*IncidentRecord, error) {

	recordJSON, err := ctx.GetStub().GetState(recordID)
	if err != nil {
		return nil, fmt.Errorf("failed to read record: %v", err)
	}
	if recordJSON == nil {
		return nil, fmt.Errorf("record %s does not exist", recordID)
	}

	var record IncidentRecord
	err = json.Unmarshal(recordJSON, &record)
	if err != nil {
		return nil, err
	}

	return &record, nil
}

func (c *DLIGDRContract) UpdateStatus(ctx contractapi.TransactionContextInterface,
	recordID string, newStatus string) error {

	recordJSON, err := ctx.GetStub().GetState(recordID)
	if err != nil {
		return fmt.Errorf("failed to read record: %v", err)
	}
	if recordJSON == nil {
		return fmt.Errorf("record %s does not exist", recordID)
	}

	var record IncidentRecord
	err = json.Unmarshal(recordJSON, &record)
	if err != nil {
		return err
	}

	record.Status = newStatus
	updatedJSON, err := json.Marshal(record)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(recordID, updatedJSON)
}

func (c *DLIGDRContract) GetAllRecords(ctx contractapi.TransactionContextInterface) ([]*IncidentRecord, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var records []*IncidentRecord
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var record IncidentRecord
		err = json.Unmarshal(queryResponse.Value, &record)
		if err != nil {
			return nil, err
		}
		records = append(records, &record)
	}

	return records, nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&DLIGDRContract{})
	if err != nil {
		fmt.Printf("Error creating DLI-DGR chaincode: %v\n", err)
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting DLI-DGR chaincode: %v\n", err)
	}
}

// LogSensitiveEvent stores sensitive identity data in a Private Data Collection
// Only authorised peers can read the actual data; all peers see the transaction hash
func (c *DLIGDRContract) LogSensitiveEvent(ctx contractapi.TransactionContextInterface,
	recordID string, agency string, eventType string) error {

	// Read sensitive data from transient map — never exposed on shared ledger
	transientData, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("failed to read transient data: %v", err)
	}

	sensitiveDetails, exists := transientData["sensitive_details"]
	if !exists {
		return fmt.Errorf("sensitive_details not found in transient data")
	}

	// Store full data in private collection — only Org1 peers can read this
	privateRecord := IncidentRecord{
		RecordID:  recordID,
		Agency:    agency,
		EventType: eventType,
		Details:   string(sensitiveDetails),
		Timestamp: time.Now().Format("2006-01-02 15:04:05"),
		Status:    "ACTIVE",
	}

	privateJSON, err := json.Marshal(privateRecord)
	if err != nil {
		return err
	}

	// Write to private collection — Aadhaar biometric data stays here
	err = ctx.GetStub().PutPrivateData("IdentityPrivateCollection", recordID, privateJSON)
	if err != nil {
		return fmt.Errorf("failed to write private data: %v", err)
	}

	// Write only non-sensitive metadata to shared ledger — all agencies see this
	publicRecord := IncidentRecord{
		RecordID:  recordID,
		Agency:    agency,
		EventType: eventType,
		Details:   "[SENSITIVE DATA — stored in private collection, hash verified]",
		Timestamp: time.Now().Format("2006-01-02 15:04:05"),
		Status:    "ACTIVE",
	}

	publicJSON, err := json.Marshal(publicRecord)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(recordID, publicJSON)
}
