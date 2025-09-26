# BrowserGrid Session Runtime Image

This Dockerfile (`docker/session-runtime/Dockerfile`) builds a production-ready Docker image for running BrowserGrid sessions. Each container instance runs a single Elixir/Phoenix application configured for one session, which can launch the `browsermux` Go binary to manage browser instances via CDP.

## Features
- **Elixir Release**: Self-contained production build of the BrowserGrid app.
- **Browsermux**: Compiled Go binary for per-session CDP API.
- **Chrome Browser**: Installed via Playwright with all necessary dependencies.
- **Non-Root User**: Runs as `browseruser` (UID/GID 1000) for security.
- **Writable Directories**: Pre-configured paths for session data, media, and profiles.
- **Healthcheck**: Monitors the app's `/health` endpoint (implement if not present).
- **Clean Shutdown**: Elixir release handles SIGTERM gracefully for session snapshotting.

## Build the Image
Build with default versions:
```
docker build -f docker/session-runtime/Dockerfile -t browsergrid/session:latest .
```

Customize versions (e.g., pin Playwright and browser):
```
docker build \
  --build-arg PLAYWRIGHT_VERSION=1.47.0 \
  --build-arg BROWSER_VERSION=120.0.0 \
  -f docker/session-runtime/Dockerfile \
  -t browsergrid/session:v1.0 .
```

**Notes**:
- Image size: ~1.5-2GB (optimized multi-stage build).
- Requires `docker/browsermux/` directory with Go source for compilation.
- For updates: Rebuild when app code, browsermux, or browser versions change.

## Run Locally
Start a session container (replace env vars as needed):
```
docker run -d \
  --name browsergrid-session \
  -p 4000:4000 \
  -e SECRET_KEY_BASE=your_64_char_secret \
  -e BROWSERGRID_SESSION_ID=session-123 \
  -e BROWSERGRID_ENV=prod \
  -v session_data:/var/lib/browsergrid/sessions \
  -v media_data:/var/lib/browsergrid/media \
  -v profiles_data:/var/lib/browsergrid/profiles \
  browsergrid/session:latest
```

**Environment Variables**:
- `SECRET_KEY_BASE`: Required for Phoenix (64+ chars).
- `BROWSERGRID_SESSION_ID`: Unique ID for this session (used by app logic).
- `BROWSERGRID_ENV`: Set to `prod` (default).
- `PORT`: App port (default 4000).
- `BROWSERGRID_SESSION_DIR`, `BROWSERGRID_MEDIA_DIR`, `BROWSERGRID_PROFILES_DIR`: Writable paths (defaults provided; mount volumes here).
- Database/Redis: Configure via `DATABASE_URL`, `REDIS_URL` if sessions need shared state.

**Volumes** (recommended for persistence):
- `/var/lib/browsergrid/sessions`: Session-specific data (e.g., snapshots).
- `/var/lib/browsergrid/media`: Downloaded media/files.
- `/var/lib/browsergrid/profiles`: Browser profiles (for rehydration).

**Access**:
- App: http://localhost:4000
- Health: http://localhost:4000/health
- Logs: `docker logs browsergrid-session`

**Shutdown**: Send SIGTERM (e.g., `docker stop`) for clean session cleanup.

## Deploy to Kubernetes
Use this as a base for session Pods. Example Deployment for a single session:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: browsergrid-session
spec:
  replicas: 1
  selector:
    matchLabels:
      app: browsergrid-session
  template:
    metadata:
      labels:
        app: browsergrid-session
    spec:
      containers:
      - name: session
        image: browsergrid/session:latest
        ports:
        - containerPort: 4000
        env:
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: browsergrid-secrets
              key: secret-key-base
        - name: BROWSERGRID_SESSION_ID
          value: "session-123"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: session-data
          mountPath: /var/lib/browsergrid/sessions
        - name: media-data
          mountPath: /var/lib/browsergrid/media
        - name: profiles-data
          mountPath: /var/lib/browsergrid/profiles
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: session-data
        persistentVolumeClaim:
          claimName: browsergrid-session-pvc
      - name: media-data
        persistentVolumeClaim:
          claimName: browsergrid-media-pvc
      - name: profiles-data
        emptyDir: {}  # Or PVC for persistence
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
---
apiVersion: v1
kind: Service
metadata:
  name: browsergrid-session-service
spec:
  selector:
    app: browsergrid-session
  ports:
  - port: 4000
    targetPort: 4000
```

**K8s Best Practices**:
- **Security**: Use non-root (already set), Secrets for sensitive env vars.
- **Resources**: Allocate 2-4GB RAM, 1-2 CPU cores per session (browser heavy).
- **Storage**: Use PVCs for persistent data; EmptyDir for temp profiles.
- **Probes**: Leverage built-in healthcheck; adjust delays for boot time.
- **Scaling**: Deploy multiple replicas or use StatefulSet for session affinity.
- **Init Containers**: If needed for setup (e.g., DB migration), add before main container.
- **Node Selector/Affinity**: Schedule on nodes with GPU/ sufficient resources if using headless browsers.
- **Shutdown**: K8s SIGTERM triggers clean Elixir shutdown (graceful period: 30s default).

## Auditing and Updates
- **Security Scans**: Run `docker scout` or Trivy on the image.
- **Version Pins**: Always pin Elixir, Go, Playwright, Ubuntu versions in CI.
- **Size Optimization**: Multi-stage keeps it lean; avoid adding unnecessary packages.
- **Testing**: Build and run integration tests (e.g., launch session, verify browser CDP).

For issues or customizations (e.g., add Firefox), extend this Dockerfile or contact the team.
