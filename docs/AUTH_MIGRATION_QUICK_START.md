# Authentication System - Quick Start

## What Changed?

✅ **Dashboard is now secure** - requires login to access
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

## Key Changes for Developers

### Before (Insecure)

```elixir
# Anyone could access dashboard
visit "/dashboard"
```

### After (Secure)

```elixir
# Must login first
visit "/users/log_in"
login("user@example.com", "password")
visit "/dashboard"  # Now works!
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
- `/users/settings` - User settings

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

## Accessing Current User in Controllers

### In Regular Controllers

```elixir
def index(conn, _params) do
  current_user = conn.assigns.current_user
  # Use current_user...
end
```


## Troubleshooting

### Problem: Can't access dashboard
**Solution:** Make sure you're logged in at `/users/log_in`

### Problem: Can't see my sessions/profiles
**Solution:** Resources are scoped per-user. You can only see your own.

### Problem: Email confirmation not working
**Solution:** In development, check `/dev/mailbox` instead of real email

## Next Steps

1. ✅ Create user account
2. ✅ Login to dashboard
3. 📖 Read full documentation: `docs/AUTHENTICATION.md`
4. 🚀 Build your application!

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

