from __future__ import annotations

import ipaddress
from fastapi import FastAPI, Header, Path, Query
from pydantic import BaseModel, Field

from src.app.errors import AppError, RequestIdMiddleware, install_error_handlers
from src.app.models import HealthOut
from src.app.settings import service_name, service_version

app = FastAPI(
    title="API Блокировки IP (ipblocker)",
    version=service_version(),
    description="Учебный API-сервис. Тема: ipblocker.",
)

app.add_middleware(RequestIdMiddleware)
install_error_handlers(app)


# --- Модели и База данных ---

# Словари в памяти (база данных). После перезапуска сервера данные пропадают.
ips_db = {}           # Формат: {"192.168.1.10": {"status": "blocked", "reason": "DDoS attack"}}
idempotency_db = {}   # Формат: {"key-1": {"ip": "192.168.1.10", "status": "blocked"}}

class BlockRequest(BaseModel):
    reason: str = Field(..., min_length=1, description="Причина блокировки")

def is_valid_ipv4(ip: str) -> bool:
    try:
        ipaddress.IPv4Address(ip)
        return True
    except ipaddress.AddressValueError:
        return False


# --- Маршруты (Эндпоинты) ---

@app.get("/health", response_model=HealthOut)
def health() -> HealthOut:
    return HealthOut(status="ok", service=service_name(), version=service_version())

@app.post("/api/v1/ips/{ip}/block")
def block_ip(
    body: BlockRequest,
    ip: str = Path(..., description="IP-адрес для блокировки"),
    idempotency_key: str = Header(..., alias="Idempotency-Key")
):
    if not is_valid_ipv4(ip):
        # Используем AppError из вашего шаблона, он сам подставит request_id!
        raise AppError(422, "validation_error", "Некорректный формат IP")

    if idempotency_key in idempotency_db:
        return idempotency_db[idempotency_key]
    
    if ip in ips_db and ips_db[ip]["status"] == "blocked":
        raise AppError(409, "conflict", "IP уже заблокирован")

    ips_db[ip] = {"status": "blocked", "reason": body.reason}
    response_data = {"ip": ip, "status": "blocked"}
    
    idempotency_db[idempotency_key] = response_data
    return response_data

@app.post("/api/v1/ips/{ip}/unblock")
def unblock_ip(ip: str = Path(...)):
    if not is_valid_ipv4(ip):
        raise AppError(422, "validation_error", "Некорректный формат IP")

    if ip not in ips_db or ips_db[ip]["status"] != "blocked":
        raise AppError(409, "conflict", "IP не был заблокирован")
    
    ips_db[ip]["status"] = "unblocked"
    return {"ip": ip, "status": "unblocked"}

@app.get("/api/v1/ips/{ip}")
def check_status(ip: str = Path(...)):
    if not is_valid_ipv4(ip):
        raise AppError(422, "validation_error", "Некорректный формат IP")

    if ip not in ips_db:
        raise AppError(404, "not_found", "IP не найден в базе")
        
    return {"ip": ip, "status": ips_db[ip]["status"]}

@app.get("/api/v1/ips")
def get_ips(page: int = Query(1, ge=1), limit: int = Query(20, ge=1, le=100)):
    blocked_ips = [
        {"ip": ip_addr, "reason": data["reason"]} 
        for ip_addr, data in ips_db.items() 
        if data["status"] == "blocked"
    ]
    
    start_idx = (page - 1) * limit
    end_idx = start_idx + limit
    paginated_items = blocked_ips[start_idx:end_idx]
    
    return {
        "items": paginated_items,
        "total": len(blocked_ips)
    }