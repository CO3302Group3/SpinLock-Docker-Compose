# SpinLock Smart Parking Platform – Docker Compose Orchestration

This directory contains the **SpinLock microservices orchestration layer**. It packages every service, gateway, broker, database, and helper needed to run the full Smart Parking solution locally or in a container-friendly production environment. The stack embraces an API Gateway security pattern, isolates internal traffic, and offers opinionated tooling for day-to-day DevOps tasks.

---

## 🔭 What You Get

- **End-to-end microservice topology** for SpinLock’s smart parking capabilities.
- Hardened **API Gateway + Nginx reverse proxy** front door with TLS termination.
- Optional **domain microservices** (parking, telemetry, onboarding, etc.) pre-wired but toggled off by default until images are available.
- **Eventing backbone** (Kafka), **IoT messaging** (Mosquitto MQTT), and **monitoring UI** (Kafka UI).
- Batteries-included **PowerShell automation** via `manage.ps1` for Windows hosts.
- Drop-in secrets management via `.env`, `service_account.env`, and `ssl/` certificates.

---

## 🗂️ Repository Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Production-focused service graph (core + infra).
| `docker-compose.dev.yml` | Development overlay enabling extra tooling and hot reload.
| `manage.ps1` | Convenience wrapper around Compose (build, pull, start, stop, logs, reset, JWT secret, etc.).|
| `mosquitto.conf` | Custom configuration for the MQTT broker.
| `nginx.conf` | Edge proxy configuration (reverse proxy, TLS, rate limiting, websockets).
| `ssl/` | Placeholder for self-signed or CA-provided cert/key pairs used by Nginx. |
| `service_account.env` | Firebase service account + JWT secret consumed by Auth service. |
| `Docker-Compose.yml` *(legacy)* | Historical compose definition; retains reference for older deployments. |

> ⚠️ Keep `service_account.env` and any real certificates untracked. They already appear in `.gitignore`; don’t remove those entries.

---

## 🏗️ System Architecture

```
┌────────────┐      ┌───────────────┐      ┌───────────────────┐
│  Clients   │ ---> │  Nginx Proxy  │ ---> │   API Gateway      │
└────────────┘      └───────────────┘      └───────────────────┘
                                                │
                   ┌────────────────────────────┴───────────────────────────┐
                   │                                                        │
             Domain Microservices                                    Infrastructure
 (Auth, Device, Parking, Alerts, Admin, ...)                  (Kafka, MQTT, DBs, Observability)
```

### Entry Tier
- **Nginx (`nginx:alpine`)** terminates TLS (ports 80/443), serves health probes (8080), and forwards WebSocket traffic for MQTT.
- **SpinLock API Gateway (`rav2001h/spinlock-api-gateway:latest`)** centralizes auth, routing, throttling, and request logging.

### Core Runtime Services
| Service | Image | Status | Highlights |
|---------|-------|--------|------------|
| User Authentication | `rav2001h/user-auth-microservice:latest` | ✅ Enabled | JWT issuance, Firebase integration, RBAC hooks. |
| Admin Management | (build locally) | ⏸️ Disabled by default | Administrative workflows, tenancy. |
| Device Telemetry | (build locally) | ⏸️ Disabled | Ingests IoT metrics into Kafka/PostgreSQL. |
| Device Onboarding | (build locally) | ⏸️ Disabled | Device registry, provisioning. |
| GeoLocation | (build locally) | ⏸️ Disabled | GIS enrichment for parking assets. |
| Parking Slot | (build locally) | ⏸️ Disabled | Availability and reservations. |
| Health Monitoring | (build locally) | ⏸️ Disabled | Probes other services, publishes alerts. |
| Alert & Event Processing | (build locally) | ⏸️ Disabled | Stream processors for Kafka topics. |
| Notification | (build locally) | ⏸️ Disabled | Push/email/SMS fan-out. |
| Logging | (build locally) | ⏸️ Disabled | Centralized log shipper. |

Toggle these services on by uncommenting them in `docker-compose.yml` and ensuring the corresponding images are either built locally or available in a registry.

### Infrastructure Pillars
- **Apache Kafka (KRaft mode)**: Durable event streaming at `kafka:29092` (internal). Default topics: `device.telemetry`, `parking.events`, `user.events`, `alerts.critical`, `notifications.queue`, `audit.logs`.
- **Kafka UI**: `http://localhost:8001` for topic browsing, consumer lag, and message inspection.
- **Eclipse Mosquitto MQTT**: Core IoT ingress at `mqtt-broker:1883` plus WebSocket bridge `mqtt-broker:9001` proxied via Nginx `/mqtt/`.
- **Optional Dev Dependencies** *(docker-compose.dev.yml)*: PostgreSQL, Redis, Portainer, Adminer — helpful during feature work.

---

## 🚀 Quick Start

1. **Install prerequisites**
   - Docker Engine 24+
   - Docker Compose v2
   - Windows PowerShell 5.1+ (or PowerShell Core / Bash if not on Windows)

2. **Seed environment files**
   ```powershell
   copy .env.example .env
   .\manage.ps1 jwt-secret             # optional: generate a random JWT secret
   notepad .env                         # set ports, image tags, network CIDRs
   notepad service_account.env          # paste compact Firebase JSON + JWT secret
   ```

   - `.env` controls generic Compose variables (published ports, image names, secrets references).
   - `service_account.env` must contain `FIREBASE_CREDENTIALS` (single-line JSON) and `JWT_SECRET_KEY` for the auth service.
   - Place any `fullchain.pem`/`privkey.pem` files inside `ssl/` and adjust `nginx.conf`/`.env` accordingly.

3. **Build/pull images**
   ```powershell
   .\manage.ps1 build   # builds local Dockerfiles (API Gateway, etc.)
   .\manage.ps1 pull    # pulls remote images defined in compose files
   ```

   Need direct Compose?
   ```powershell
   docker compose build
   docker compose pull
   ```

4. **Launch the stack**
   - **Production profile** (minimal footprint):
     ```powershell
     .\manage.ps1 start
     # alt
     docker compose up -d
     ```
   - **Development profile** (extra services, live reload mounts):
     ```powershell
     .\manage.ps1 start-dev
     # alt
     docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
     ```

5. **Observe status and logs**
   ```powershell
   .\manage.ps1 status
   .\manage.ps1 logs                # tail every container
   .\manage.ps1 logs api-gateway    # focus on a single service
   docker compose ps
   ```

---

## 🌐 Access Points

| Endpoint | URL/Port | Description |
|----------|----------|-------------|
| Nginx HTTP | `http://localhost` (80) | Primary entry point (routes to API Gateway). |
| Nginx HTTPS | `https://localhost` (443) | TLS-secured ingress (requires certs in `ssl/`). |
| Nginx Health | `http://localhost:8080/health` | Gateway heartbeat; `/status` exposes stub metrics. |
| SpinLock API Gateway | `http://api-gateway:8000` (internal) | Downstream routing for microservices. |
| Kafka UI | `http://localhost:8001` | Observability for Kafka topics/consumers. |
| Mosquitto MQTT | `mqtt://mqtt-broker:1883` (internal) | Native MQTT broker endpoint. |
| Mosquitto WebSocket | `ws://localhost/mqtt/` | Web clients via Nginx WebSocket proxy. |

---

## 🔐 Security Blueprint

1. **API Gateway enforcement**: All REST traffic flows through Nginx ➜ API Gateway. JWT validation, route authorization, and rate limits live here.
2. **Network isolation**: Only Nginx and Kafka UI publish host ports. All other containers communicate over the `microservices-network` bridge.
3. **Secrets discipline**: `.env`, `service_account.env`, and TLS files kept local. Consider Docker secrets or Vault in production.
4. **Transport security**: Provide certificates in `ssl/` and switch Nginx to enforce HTTPS-only by editing `nginx.conf`.
5. **Defense in depth checklist**
   - [ ] Rotate JWT secrets regularly (`manage.ps1 jwt-secret`).
   - [ ] Disable Kafka UI port in production (`ports:` block in compose).
   - [ ] Enable Web Application Firewall (AWS WAF / Cloudflare) upstream if public facing.
   - [ ] Centralize audit logs (enable `Logging` microservice and point to ELK/Loki).
   - [ ] Restrict Docker host firewall to published ports only.

---

## ⚙️ Configuration Highlights

### Environment Variables

| Key | Default | Consumed By | Notes |
|-----|---------|-------------|-------|
| `JWT_SECRET_KEY` | _(generated)_ | API Gateway, Auth | Must match value inside `service_account.env`. |
| `JWT_ALGORITHM` | `HS256` | Auth | Change only if every issuer/consumer agrees. |
| `DATABASE_URL` | n/a | Domain services | Set when enabling services needing persistence. |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:29092` | Event clients | Matches internal service name. |
| `MQTT_BROKER_URL` | `mqtt-broker` | Device services | Use `wss://` via Nginx for browsers. |
| `LOG_LEVEL` | `INFO` | Most services | Elevate to `DEBUG` in dev overlay. |

### Volumes
- `kafka_data`, `kafka_logs`: Kafka durability.
- `mqtt_data`: Mosquitto persistence.
- `user_auth_data`: Auth DB snapshots (if the service mounts a volume).
- Additional dev-mode volumes: `postgres_data`, `redis_data`, `portainer_data`.

### Network
- Default bridge: `microservices-network` (`172.20.0.0/16`). Override subnet via `.env` if necessary.

---

## 🧪 Validation & Smoke Tests

```powershell
# Gateway availability
Invoke-RestMethod -Uri "http://localhost/health" -Method GET

# Auth service via routed path
Invoke-RestMethod -Uri "http://localhost/auth/health" -Method GET

# MQTT readiness (requires MQTT client)
docker exec mqtt-broker mosquitto_pub -t "spinlock/ping" -m "hello"

# Kafka topic listing
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Kafka UI reachability
Invoke-RestMethod -Uri "http://localhost:8001" -Method GET
```

For end-to-end device tests, sample MQTT/WebSocket clients live in `../test/` (see `mqtt_client.py`, `websocket_mqtt_client.py`).

---

## 🧰 Day‑to‑Day Operations

| Action | PowerShell | Compose Equivalent |
|--------|------------|--------------------|
| Build local images | `./manage.ps1 build` | `docker compose build` |
| Pull remote images | `./manage.ps1 pull` | `docker compose pull` |
| Start (prod) | `./manage.ps1 start` | `docker compose up -d` |
| Start (dev) | `./manage.ps1 start-dev` | `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d` |
| Stop | `./manage.ps1 stop` | `docker compose down` |
| Restart | `./manage.ps1 restart` | `docker compose down; docker compose up -d` |
| Tail logs | `./manage.ps1 logs` | `docker compose logs -f` |
| Logs (service) | `./manage.ps1 logs user-auth-service` | `docker compose logs -f user-auth-service` |
| Reset volumes | `./manage.ps1 reset` | `docker compose down -v` |
| Help/usage | `./manage.ps1 help` | — |
| Generate JWT secret | `./manage.ps1 jwt-secret` | — |

> Linux/macOS users can execute the same script via `pwsh ./manage.ps1 <command>` or translate commands to shell aliases.

---

## 🔄 Enabling Additional Microservices

1. Build or pull the service image (e.g., `docker build -t spinlock-device-telemetry ../DeviceTelemetry`).
2. Uncomment the relevant service block in `docker-compose.yml`.
3. Provide the service-specific environment variables in `.env` or a dedicated `env_file`.
4. Run `./manage.ps1 restart` to recreate containers with the new components.

Consider staging them one at a time and monitoring logs to ensure Kafka topics, databases, and MQTT channels align with expectations.

---

## 🧑‍💻 Development Tips

- **Hot reload**: The dev overlay mounts local source directories into containers where supported. Ensure Python containers run with `--reload` or equivalent.
- **Debugging**: Attach shells using `docker exec -it <service> /bin/sh` (or `/bin/bash`). Use `ping`, `curl`, and `nc` to validate service-to-service reachability.
- **Testing locally developed services**: Rebuild frequently (`./manage.ps1 build <service>` variant if you add one) and restart only the impacted containers with `docker compose up -d <service>`.
- **Database fixtures**: If using the dev Postgres instance, expose migrations/seed scripts through mounted volumes or `docker exec` commands.

---

## 🩺 Troubleshooting

| Symptom | Possible Cause | Resolution |
|---------|----------------|------------|
| `port already allocated` | Host port conflict | Stop conflicting process (`Get-Process -Id (Get-NetTCPConnection -LocalPort 80).OwningProcess`) or change exposed port in `.env`.
| `JWT verification failed` | Secrets mismatch | Regenerate via `./manage.ps1 jwt-secret` and update every consumer + `service_account.env`.
| `Gateway returns 502` | Downstream service unhealthy | Inspect container logs, ensure internal DNS name matches `nginx.conf` upstream block.
| Kafka UI blank | Broker not reachable | Verify Kafka is running (`docker compose ps kafka`), check `KAFKA_BROKER_ID`/listeners.
| MQTT clients can’t connect | Missing TLS/WS config | Confirm Nginx `/mqtt/` location, ensure correct protocol (`mqtt://` vs `wss://`).

Health probes cheat sheet:
```powershell
Invoke-RestMethod -Uri "http://localhost/status" -Method GET         # API Gateway status
Invoke-RestMethod -Uri "http://localhost:8080/health" -Method GET    # Nginx health
docker exec api-gateway curl -sf http://user-auth-service:8000/health
```

---

## 🤝 Contributing & Next Steps

1. Spin up the stack (`./manage.ps1 start-dev`) and validate new features against real infrastructure.
2. Keep documentation in sync—update this README when enabling new services or changing network contracts.
3. Add unit/integration tests in their respective service repos; wire them into CI/CD before publishing new images.
4. Roadmap ideas:
   - Automate certificate provisioning (Let’s Encrypt / mkcert) via `manage.ps1` subcommand.
   - Add Grafana + Prometheus in dev overlay for richer observability.
   - Wire `Logging` microservice to Loki/S3 for long-term retention.

---

## 📄 License

The SpinLock orchestration is part of the **CO330 Smart Parking** project. License terms follow the root repository’s policy; ensure compliance before reuse in other contexts.
