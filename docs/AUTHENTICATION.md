# Browsergrid Authentication System

## Overview

Browsergrid implements a **user authentication** system for human users accessing the dashboard.

The system uses a provider-agnostic architecture that allows seamless migration from Phoenix.Auth to Clerk or other providers.

## Architecture

### Core Components

```
lib/browsergrid/
├── auth/
│   ├── provider.ex              # Behavior definition
│   ├── phoenix_provider.ex      # Phoenix.Auth implementation
│   └── clerk_provider.ex        # Future: Clerk implementation
├── auth.ex                      # Unified public API
└── accounts/
    ├── user.ex                  # User schema
    ├── user_token.ex           # Session tokens
    └── user_notifier.ex        # Email notifications
```

## Authentication Flow

### Dashboard Login (User Auth)

```
User → /users/log_in → UserSessionController.create
                      ↓
            Phoenix.Auth.authenticate(email, password)
                      ↓
            Set session cookie
                      ↓
            Redirect to /dashboard
```

## Key Features

### 1. Provider Abstraction

The `Browsergrid.Auth.Provider` behavior defines the interface that all authentication providers must implement:

```elixir
@callback authenticate(email :: String.t(), password :: String.t()) ::
            {:ok, User.t()} | {:error, atom()}
@callback register(attrs :: map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
@callback verify_session(token :: String.t()) :: {:ok, User.t()} | {:error, atom()}
@callback revoke_session(token :: String.t()) :: :ok
@callback generate_session_token(user :: User.t()) :: String.t()
@callback current_user(conn :: Plug.Conn.t()) :: User.t() | nil
```

### 2. Ownership Model

All resources now have a `user_id` foreign key:
- **Sessions** belong to users
- **Profiles** belong to users
- **Deployments** belong to users

This enables:
- Per-user resource isolation
- Audit trails
- Permission management

### 3. Router Protection

Routes are now properly secured:

```elixir
# Public routes (no authentication)
scope "/", BrowsergridWeb do
  pipe_through :browser
  get "/", PageController, :home
end

# Protected routes (authentication required)
scope "/", BrowsergridWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  get "/dashboard", DashboardController, :overview
  get "/sessions", SessionController, :index
  get "/profiles", ProfileController, :index
  # ... etc
end
```

## Usage

### User Registration & Login

1. **Register a new user:**
   - Navigate to `/users/register`
   - Fill in email and password
   - Confirm email (check `/dev/mailbox` in development)

2. **Login:**
   - Navigate to `/users/log_in`
   - Enter email and password
   - Redirected to dashboard

3. **Logout:**
   - Click logout button (sends DELETE to `/users/log_out`)

### Scoping Resources by User

All contexts now support filtering by user:

```elixir
# Sessions
sessions = Browsergrid.Sessions.list_sessions(user_id: user.id)

# Profiles
profiles = Browsergrid.Profiles.list_profiles(user_id: user.id)

# Deployments
deployments = Browsergrid.Deployments.list_deployments(user_id: user.id)
```

### Creating Resources with User Context

When creating resources, pass the user_id:

```elixir
# Create session for user
{:ok, session} = Browsergrid.Sessions.create_session(%{
  name: "My Session",
  browser_type: :chrome,
  user_id: user.id
})

# Create profile for user
{:ok, profile} = Browsergrid.Profiles.create_profile(%{
  name: "My Profile",
  browser_type: :chrome,
  user_id: user.id
})
```

## Configuration

### Switching Authentication Providers

To switch from Phoenix.Auth to another provider (e.g., Clerk):

1. **Implement the provider:**

```elixir
defmodule Browsergrid.Auth.ClerkProvider do
  @behaviour Browsergrid.Auth.Provider
  
  def authenticate(email, password) do
    # Clerk uses redirect-based auth, not password
    {:error, :use_clerk_redirect}
  end
  
  def verify_session(jwt_token) do
    # Verify Clerk JWT
    # Extract user_id from claims
    # Find or create local user record
  end
  
  # ... implement other callbacks
end
```

2. **Update configuration:**

```elixir
# config/config.exs
config :browsergrid,
  auth_provider: Browsergrid.Auth.ClerkProvider
```

3. **Update router** (if needed for OAuth flows)

That's it! All authentication calls go through `Browsergrid.Auth`, which delegates to the configured provider.

## Security Considerations

### Session Security
- Sessions use signed cookies with CSRF protection
- Remember-me tokens are valid for 60 days
- Session IDs are renewed on login to prevent fixation attacks

### Resource Isolation
- All queries scoped by user_id
- Foreign key constraints enforce ownership
- User deletion sets resources to nil (audit preservation)

## Database Schema

### Users Table

```sql
CREATE TABLE users (
  id uuid PRIMARY KEY,
  email citext UNIQUE NOT NULL,
  hashed_password varchar(255) NOT NULL,
  confirmed_at timestamp,
  inserted_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);
```

### Updated Tables with user_id

```sql
ALTER TABLE sessions ADD COLUMN user_id uuid REFERENCES users(id) ON DELETE NILIFY ALL;
ALTER TABLE deployments ADD COLUMN user_id uuid REFERENCES users(id) ON DELETE NILIFY ALL;
-- profiles already had user_id
```

## Testing

### Manual Testing

1. **Start the server:**
   ```bash
   mix phx.server
   ```

2. **Register a user:**
   - Visit http://localhost:4000/users/register
   - Fill in email/password
   - Check http://localhost:4000/dev/mailbox for confirmation

3. **Confirm email** (click link in mailbox)

4. **Login** at `/users/log_in`

5. **Access dashboard** at `/dashboard` (should work)

6. **Try without login:**
   - Logout
   - Visit `/dashboard` → should redirect to login

### Automated Testing

Run existing tests (updated to handle authentication):

```bash
mix test
```

## Migration Guide

### For Existing Installations

If you have existing data, follow these steps:

1. **Run migrations:**
   ```bash
   mix ecto.migrate
   ```

2. **Create a system user** (optional, for existing resources):
   ```elixir
   # In iex -S mix
   {:ok, system_user} = Browsergrid.Auth.register(%{
     email: "system@browsergrid.local",
     password: "changeme123"
   })
   ```

3. **Or allow null user_ids** (less secure, but preserves existing data)

## Troubleshoties

### "You must log in to access this page"
- You're trying to access a protected route without authentication
- Solution: Login at `/users/log_in`

### "Forbidden" when accessing session/profile
- Resource doesn't belong to your user
- Solution: Only access your own resources

### Email confirmation not working
- Check `/dev/mailbox` in development
- In production, configure proper email adapter in `runtime.exs`

## Roadmap

### Phase 1: Foundation ✅
- [x] Generate Phoenix.Auth base
- [x] Create provider abstraction
- [x] Add user_id to resources
- [x] Protect dashboard routes

### Phase 2: Enhanced Security (Future)
- [ ] Two-factor authentication (TOTP)
- [ ] OAuth providers (GitHub, Google)

### Phase 3: Clerk Integration (Future)
- [ ] Implement ClerkProvider
- [ ] Update router for OAuth flows
- [ ] Migrate existing users
- [ ] SSO support

### Phase 4: Multi-tenancy (Future)
- [ ] Organizations/Teams
- [ ] Role-based access control
- [ ] Resource sharing
- [ ] Admin panel

## References

- [Phoenix Authentication Guide](https://hexdocs.pm/phoenix/authentication.html)
- [phx.gen.auth Documentation](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html)
- [Argon2 Password Hashing](https://hexdocs.pm/argon2_elixir/)
- [Clerk Documentation](https://clerk.com/docs) (for future integration)

## Support

For questions or issues, please:
1. Check this documentation
2. Review the code in `lib/browsergrid/auth/`
3. Check existing GitHub issues
4. Create a new issue with details

