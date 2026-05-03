from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import json
import time
import asyncio

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class LoginRequest(BaseModel):
    driver_id: str
    pin: str

class BusRegisterRequest(BaseModel):
    driver_id: str
    driver_name: str
    phone: str
    bus_number: str
    plate_number: str
    capacity: int
    pin: str

# Persistent storage
STATE_FILE = "state.json"

def load_state():
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except:
        return {
            "is_logged_in": False,
            "driver_id": "",
            "driver_name": "N/A",
            "phone": "N/A",
            "bus_number": "N/A",
            "plate_number": "N/A",
            "capacity": 32,
            "pin": "1234",
            "is_on_trip": False
        }

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

driver_state = load_state()

@app.get("/get_state")
async def get_state():
    return driver_state

@app.post("/login")
async def login(req: LoginRequest):
    if req.pin == driver_state.get("pin", "1234"):
        driver_state["is_logged_in"] = True
        driver_state["driver_id"] = req.driver_id
        save_state(driver_state)
        return {"status": "success", "message": "Logged in"}
    return {"status": "error", "message": "Invalid PIN"}

@app.post("/register_bus")
async def register_bus(req: BusRegisterRequest):
    driver_state["driver_id"] = req.driver_id
    driver_state["driver_name"] = req.driver_name
    driver_state["phone"] = req.phone
    driver_state["bus_number"] = req.bus_number
    driver_state["plate_number"] = req.plate_number
    driver_state["capacity"] = req.capacity
    driver_state["pin"] = req.pin
    save_state(driver_state)
    return {"status": "success"}

@app.post("/start_trip")
async def start_trip():
    driver_state["is_on_trip"] = True
    save_state(driver_state)
    return {"status": "success"}

@app.post("/end_trip")
async def end_trip():
    driver_state["is_on_trip"] = False
    save_state(driver_state)
    return {"status": "success"}

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

manager = ConnectionManager()
current_data = {
    "seated": 0, 
    "standing": 0, 
    "latitude": 14.5995, 
    "longitude": 120.9842, 
    "last_update": 0, 
    "is_active": False
}

async def auto_reset_task():
    global current_data
    while True:
        await asyncio.sleep(1)
        if time.time() - current_data["last_update"] > 10:
            if current_data["is_active"]:
                current_data["is_active"] = False
                await manager.broadcast(json.dumps({
                    "seated": 0, 
                    "standing": 0,
                    "is_active": False
                }))

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(auto_reset_task())

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    await websocket.send_text(json.dumps({
        "seated": current_data["seated"], 
        "standing": current_data["standing"],
        "latitude": current_data["latitude"],
        "longitude": current_data["longitude"],
        "is_active": current_data["is_active"]
    }))
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.post("/update")
async def update_status(data: dict):
    global current_data
    current_data["seated"] = data.get("seated", current_data["seated"])
    current_data["standing"] = data.get("standing", current_data["standing"])
    if "latitude" in data: current_data["latitude"] = data["latitude"]
    if "longitude" in data: current_data["longitude"] = data["longitude"]
    
    current_data["last_update"] = time.time()
    current_data["is_active"] = True
    
    await manager.broadcast(json.dumps({
        "seated": current_data["seated"], 
        "standing": current_data["standing"],
        "latitude": current_data["latitude"],
        "longitude": current_data["longitude"],
        "is_active": True,
        "is_on_trip": driver_state["is_on_trip"],
        "bus_number": driver_state["bus_number"],
        "plate_number": driver_state["plate_number"],
        "capacity": driver_state["capacity"]
    }))
    return {"status": "success"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
