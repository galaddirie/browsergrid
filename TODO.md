- [ ] Profile integration
- [ ] Add session state machine and reconilliation worker
- [x] connect to phoneix channels for streaming
- [x] use sonnar instead of phoneix flash messages
- [ ] default to chromium on arm64 systems ( mac with m1/m2/m3, linux arm64, etc )
- [x] Edge routing ( session/:id/edge/* should proxy to session host )

- [ ] Webhook integration





- [ ] adding CUA endpoint for browser
    - [ ] add visual ( similar to chatgpt where we should a  rendering  similar to this https://screen.studio/?aff=Yy75o )
    - [ ] chat  (jido agents?)
    - Note: our chat feature will likely need to use pooled sessions for fast acquisition and efficient use of resources
    - we wouldnt want to constinantly cycle through sessions in a chat like evironment where user requests are frequent
    - we would need to figure out how to handle the session lifecycle in a chat like environment
    - we would want to keep the user browser state active and wouldnt want to charge users for the idle time between chat messages
      - ex. message 1: user asks for a visit a website, 10 minutes later message 2: user asks to do an action this page. 
      - do we charge for the 10 minutes of idle time?
      - would we create a profile for each chat and keep that profile hot swaping it into an available node each time the user sends a message?
      - would it be possible to restore the near exact state of the browser from the previous message?
      -maybe add a flag for persistant chat browser sessions and warn users that they will be charged for the idle time between messages while the chat window is open
- [ ] test to see if we can test 1 million sessions ( fake pods/containers) 

- [ ] Deployment integration
- [ ] intercept cdp events and animate the ffmpeg webm stream sort of like a live action replay like https://screen.studio/
- [ ] match the stream output to the browser window size and aspect ratio, ensure the video frontend also handles any aspect ratio

## Connect Endpoint

- [ ] Stand up **wss://connect.browsergrid.com** and **https://connect.browsergrid.com**
  - [ ] Maintain a **pool of idle browser nodes** for fast acquisition (never previously used)
  - [ ] Use this origin to **claim an idle session** for a user
  - [ ] **Separate connect.* in prod** so the WebSocket surface can scale independently (Elixir, libcluster, K8s, dedicated LBs)

## Local Dev / Routing

- [ ] For local dev (no subdomain routing), provide a **path-based fallback** (e.g., `http://localhost:4000/connect/...`)
  - [ ] Make subdomain vs path routing **configurable** (env flag)

## Legacy Endpoint Changes

- [ ] **Remove WebSocket support** from `/sessions/:id/edge/*` proxy
  - [ ] Keep it **read-only** for browser JSON and WebM stream

## Session Claiming & Lifecycle

- [ ] Add `?token=` param to **claim** a session (this token for now will be a environment variable)
  - [ ] `GET https://connect.browsergrid.com/json?token=...` → mark session **claimed/running**
  - [ ] Once claimed, session is **not available** to others
  - [ ] **Wait up to 10s** for the client to open the WebSocket; if no WS connects, **delete** the session
- [ ] WebSocket handling:
  - [ ] Client connects: `wss://connect.browsergrid.com/json?token=...`
  - [ ] On WS **disconnect**, **delete** the session immediately

## Ops / Hardening (nice-to-have)

- [ ] Rate limit & IP stickiness on `connect.*`
- [ ] Strict Origin allowlist for browser-based WS clients
- [ ] Health checks/metrics per-session and for the idle pool


# API Key / Token System

## Scope & Terminology
- [ ] Single **admin API key** system (no user accounts yet)
- [ ] Accepted via **HTTP header** or **URL param**
- [ ] Use consistent naming: header `Authorization: Bearer <token>`; query `?token=<token>`
- [ ] require token to be present in api requests and connect/ claim requests

---

## Data Model & Storage
- [ ] Create `api_keys` table (id, name/label, key_hash, prefix, last4, created_at, revoked_at, expires_at (nullable), created_by, last_used_at, usage_count, metadata JSONB)
- [ ] Store **only a hash** of the key (Argon2id). Never store raw key after creation
- [ ] Save short **prefix** (e.g., `bg_`) + **last 4** for display & lookup UX
- [ ] Optional: `scope` (string/enum) for future scoping; default `admin`

---

## Key Format & Generation
- [ ] Generate 32–40 bytes cryptographically random → base62/base64url
- [ ] Final string: `bg_<prefix>_<random>`, e.g., `bg_DH9K_<…>`
- [ ] Return raw key **once** on create/regenerate; show warning about safe storage
- [ ] Enforce minimum length check and prefix validation in middleware

---

## Auth Middleware (Elixir/Phoenix)
- [ ] Plug to extract key:
  - [ ] Header: `Authorization: Bearer <token>`
  - [ ] Fallback: query param `token`
- [ ] Normalize + constant-time compare against stored **hash**
- [ ] Check `revoked_at` and `expires_at`
- [ ] On success: assign `conn.assigns.token` (id, scope, metadata)
- [ ] On failure: return `401 {"error":"invalid_token"}` (no detail leaks)
- [ ] Add per-key **rate limit** (e.g., ETS/Redis token bucket)


## Inertia Frontend
- [ ] List keys (label, prefix+last4, created_at, last_used_at, usage_count, status)
- [ ] Create key modal (name/label, optional expiry); show raw once + “Copy” button
- [ ] Regenerate flow (hard confirm); show new raw; mark old revoked
- [ ] Revoke action with confirmation
- [ ] Helpful snippets (curl/JS) showing header and query usage
- [ ] UX warnings: “Treat like a password. You won’t see this again.”
