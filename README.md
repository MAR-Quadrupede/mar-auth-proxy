# M.A.R. — Auth Proxy & Zero-Trust Remote Ingress (`mar-auth-proxy`)

Questo microservizio gestisce in modo centralizzato e sicuro l'esposizione pubblica su Internet e il controllo accessi remoto di tutta la piattaforma robotica **M.A.R. (Multi-legged Autonomous Robot)** su Raspberry Pi 5 all'interno del cluster Kubernetes K3s (namespace `mar-system`).

---

## 1. Architettura & Componenti

Il microservizio opera come pod multi-container (o stack Docker Compose) composto da 3 componenti cooperanti:

1. **Cloudflare Tunnel (`cloudflared`)**:
   - Mantiene un tunnel outbound cifrato verso i POP edge Cloudflare globali (protocollo QUIC/HTTP2).
   - Nessuna porta in entrata aperta sul router locale o hotspot 4G (Zero Open Ports / NAT bypass).
   - Token Tunnel gestito in modo sicuro tramite Kubernetes Secret (`mar-auth-secrets`) o variabile d'ambiente (`CLOUDFLARE_TUNNEL_TOKEN`).

2. **Caddy Reverse Proxy (`caddy`)**:
   - Riceve il traffico instradato dal tunnel su porta 80 e porta 443 (con TLS interno per accesso a bassa latenza su rete locale).
   - Applica la direttiva `forward_auth` interrogando Authelia per ogni richiesta HTTP/WebSocket.
   - Trasmette i claim di autenticazione (`Remote-User`, `Remote-Groups`).
   - Supporta il full-duplex WebSocket (`flush_interval -1`) e streaming video MJPEG a latenza ultra-bassa.

3. **Authelia SSO (`authelia`)**:
   - Server di autenticazione e Single Sign-On leggero e hardened.
   - Dominio cookie di sessione: `gianlucamorello.it` (`name: mar_session`).
   - Session store ad alte prestazioni integrato con Redis (`mar-redis:6379`).
   - Policy predefinita: `default_policy: deny`.
   - Protezione brute-force e rate-limiting (`regulation`).

---

## 2. Mappatura Sottodomini & Servizi

| Sottodominio Pubblico | Servizio Destinazione Interno | Descrizione |
| :--- | :--- | :--- |
| `https://auth-mar.gianlucamorello.it` | `authelia:9091` | Portale di Login SSO e gestione sessione |
| `https://mar-dashboard.gianlucamorello.it` | `mar-dashboard:3000` | Console Web Operatore Next.js |
| `https://mar-vision.gianlucamorello.it` | `mar-vision-service:8443` | Stream video 3D stereo, mappa 2D e calibrazione |
| `https://mar-gateway.gianlucamorello.it` | `mar-gateway:8765` | Gateway WebSocket & Telemetria Real-Time |
| `https://mar-api.gianlucamorello.it` | `mar-gateway:8765` | API REST di controllo remoto e comandi |
| `https://mar-grafana.gianlucamorello.it` | `grafana:3000` | Dashboard metriche meccatroniche |
| `https://mar-prometheus.gianlucamorello.it` | `prometheus:9090` | Time-Series Database e metriche sistema |
| `https://mar-portainer.gianlucamorello.it` | `portainer:9000` | Gestione container e cluster Kubernetes |
| `https://mar-s3.gianlucamorello.it` | `mar-s3:9001` | MinIO S3 Object Storage Web Console |

---

## 3. Gestione Utenti e Controllo Accessi

I ruoli e le credenziali sono configurati tramite il backend file di Authelia (`users_database.yml` o secret montato):

- **Gruppo `admins`**: Accesso completo a tutti i microservizi M.A.R., console di monitoraggio (Grafana, Prometheus, Portainer) e storage MinIO S3.
- **Gruppo `mar`**: Accesso operativo alla dashboard robotica, ai flussi video e ai comandi di teleoperazione.

Tutte le password e le chiavi di crittografia di sessione/storage sono gestite tramite variabili d'ambiente e Kubernetes Secrets (`mar-auth-secrets`).

---

## 4. CI/CD On-Edge

Il repository implementa la pipeline GitHub Actions `.github/workflows/build.yml` eseguita sul self-hosted runner dedicato `rpi5-mar-auth-proxy` direttamente su Raspberry Pi 5 ARM64. Ogni commit sul branch `main` applica automaticamente le modifiche a Kubernetes e verifica lo stato del rollout.
