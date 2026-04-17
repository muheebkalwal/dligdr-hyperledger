from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import subprocess

app = FastAPI()

# Request model
class IncidentSummary(BaseModel):
    state_hash: str
    origin: str

@app.post("/api/v1/log-incident", status_code=201)
async def log_incident(summary: IncidentSummary):
    print(f"📡 RECEIVED FROM WINDOWS: {summary.state_hash}")

    try:
        # 🔥 Call your working bridge.py
        result = subprocess.run(
            ["python3", "dligdr-bridge/bridge.py"],
            capture_output=True,
            text=True
        )

        print("----- BRIDGE OUTPUT -----")
        print(result.stdout)

        if result.returncode != 0:
            print("----- ERROR -----")
            print(result.stderr)
            raise Exception("Bridge execution failed")

        print("📝 SUCCESSFULLY WRITTEN TO FABRIC")

        return {
            "status": "success",
            "message": "Summary committed via bridge"
        }

    except Exception as e:
        print(f"❌ FABRIC ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3000)