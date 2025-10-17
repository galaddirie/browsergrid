# Authentication System - Quick Start

## What Changed?

✅ **Dashboard is now secure** - requires login to access
✅ **API remains protected** - API keys still work as before
✅ **User ownership** - all resources belong to users
✅ **Provider-agnostic** - easy to switch to Clerk later

## First Time Setup

### 1. Start the Server

```bash
cd /mnt/c/Users/Galad/Documents/browsergrid
mix phx.server
```

### 2. Create Your First User

Visit: http://localhost:4000/users/register

- Enter email: `admin@browsergrid.local`
- Enter password: `SecurePassword123!`
- Click "Create account"

### 3. Confirm Email (Development)

Visit: http://localhost:4000/dev/mailbox

- Click the confirmation link in the email

### 4. Login

Visit: http://localhost:4000/users/log_in

- Enter your credentials
- You'll be redirected to `/dashboard`

### 5. Create Your First API Key

Visit: http://localhost:4000/api-keys

- Click "Create API Key"
- Give it a name: "My First Key"
- **IMPORTANT:** Copy the token immediately (shown only once!)

Example token: `bg_K8H3_abcd1234...xyz789`

### 6. Test the API

```bash
# List your sessions
curl -H "Authorization: Bearer bg_K8H3_..." \
     http://localhost:4000/api/v1/sessions

# Create a session
curl -X POST \
     -H "Authorization: Bearer bg_K8H3_..." \
     -H "Content-Type: application/json" \
     -d '{"name": "Test Session", "browser_type": "chrome"}' \
     http://localhost:4000/api/v1/sessions
```

## Key Changes for Developers

### Before (Insecure)

```elixir
# Anyone could access dashboard
visit "/dashboard"

# API keys had no owner
ApiKeys.create_api_key(%{name: "Key"})
```

### After (Secure)

```elixir
# Must login first
visit "/users/log_in"
login("user@example.com", "password")
visit "/dashboard"  # Now works!

# API keys belong to users
Auth.create_api_key_for_user(user, %{name: "Key"})
```

### Creating Resources with User Context

**Sessions:**
```elixir
Sessions.create_session(%{
  name: "My Session",
  browser_type: :chrome,
  user_id: current_user.id  # <-- ADD THIS
})
```

**Profiles:**
```elixir
Profiles.create_profile(%{
  name: "My Profile",
  browser_type: :chrome,
  user_id: current_user.id  # <-- ADD THIS
})
```

**Deployments:**
```elixir
Deployments.create_deployment(%{
  name: "My Deployment",
  archive_path: "/path/to/archive.zip",
  start_command: "npm start",
  user_id: current_user.id  # <-- ADD THIS
})
```

### Filtering Resources by User

```elixir
# Get only the current user's sessions
Sessions.list_sessions(user_id: current_user.id)

# Get only the current user's profiles
Profiles.list_profiles(user_id: current_user.id)

# Get only the current user's deployments
Deployments.list_deployments(user_id: current_user.id)

# Get only the current user's API keys
ApiKeys.list_api_keys(user_id: current_user.id)
```

## Router Changes

### Public Routes (No Auth Required)
- `/` - Home page
- `/users/register` - Registration
- `/users/log_in` - Login
- `/users/reset_password` - Password reset
- `/api/health` - Health check

### Protected Routes (Login Required)
- `/dashboard` - Dashboard overview
- `/sessions` - Session management
- `/profiles` - Profile management
- `/deployments` - Deployment management
- `/api-keys` - API key management
- `/users/settings` - User settings

### API Routes (API Key Required)
- `/api/v1/*` - All API endpoints

## Common Tasks

### Change Password

1. Visit `/users/settings`
2. Fill in current and new password
3. Click "Change password"

### Reset Password (Forgot)

1. Visit `/users/reset_password`
2. Enter your email
3. Check `/dev/mailbox` for reset link
4. Click link and set new password

### Logout

Click the "Log out" button in the navbar or visit `/users/log_out`

### Revoke API Key

1. Visit `/api-keys`
2. Find the key to revoke
3. Click "Revoke"
4. Key is immediately invalid

### Regenerate API Key

1. Visit `/api-keys`
2. Find the key to regenerate
3. Click "Regenerate"
4. Old key is revoked, new key is created
5. Copy the new token immediately!

## Accessing Current User in Controllers

### In Regular Controllers

```elixir
def index(conn, _params) do
  current_user = conn.assigns.current_user
  # Use current_user...
end
```

### In API Controllers (with API Key)

```elixir
def index(conn, _params) do
  current_user = conn.assigns.current_user  # From API key
  api_key = conn.assigns.api_key
  
  # API keys now have an associated user
  sessions = Sessions.list_sessions(user_id: current_user.id)
  render(conn, :index, sessions: sessions)
end
```

## Troubleshooting

### Problem: Can't access dashboard
**Solution:** Make sure you're logged in at `/users/log_in`

### Problem: API returns 401 Unauthorized
**Solution:** Check your Bearer token is correct and not revoked

### Problem: Can't see my sessions/profiles
**Solution:** Resources are scoped per-user. You can only see your own.

### Problem: Email confirmation not working
**Solution:** In development, check `/dev/mailbox` instead of real email

## Next Steps

1. ✅ Create user account
2. ✅ Login to dashboard
3. ✅ Create API key
4. ✅ Test API with key
5. 📖 Read full documentation: `docs/AUTHENTICATION.md`
6. 🚀 Build your application!

## Future: Migrating to Clerk

When you're ready to switch to Clerk:

1. Implement `Browsergrid.Auth.ClerkProvider`
2. Update `config/config.exs`:
   ```elixir
   config :browsergrid,
     auth_provider: Browsergrid.Auth.ClerkProvider
   ```
3. Update router for OAuth flows
4. Done! All code using `Browsergrid.Auth` will work unchanged

The provider abstraction ensures zero code changes in your controllers and contexts.

