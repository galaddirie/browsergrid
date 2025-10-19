// Browser and Session Types
export type Browser = 'chrome' | 'chromium' | 'firefox';
export type BrowserVersion = 'latest' | 'stable' | 'canary' | 'dev';
export type OperatingSystem = 'linux' | 'windows' | 'macos';

// User Interface
export interface User {
  id: string;
  email: string;
  is_admin: boolean;
}

// Configuration Interfaces
export interface ScreenConfig {
  width: number;
  height: number;
  dpi: number;
  scale: number;
}

export interface ResourceLimits {
  cpu?: number;
  memory?: string;
  timeout_minutes?: number;
}

// Session Interface (matches backend Ecto schema)
export interface Session {
  id?: string;
  name?: string;
  browser_type: Browser;
  status?: string;
  live_url?: string;
  stream_url?: string;
  cluster?: string;
  profile_id?: string;
  headless?: boolean;
  timeout?: number;
  ttl_seconds?: number | null;
  screen?: ScreenConfig | null;
  limits?: ResourceLimits | null;
  session_pool_id?: string;
  session_pool?: SessionPoolSummary;
  inserted_at?: string;
  updated_at?: string;
  claimed_at?: string;
  attachment_deadline_at?: string;
  user_id?: string;
  // Optional relations when preloaded
  profile?: Profile;
  user?: User;
}

export interface PoolOwner {
  id?: string;
  email?: string;
}

export interface SessionPoolStatistics {
  ready: number;
  warming: number;
  claimed: number;
  running: number;
  errored: number;
}

export interface PoolTemplate {
  browser_type?: Browser;
  headless?: boolean;
  timeout?: number;
  ttl_seconds?: number | null;
  profile_id?: string;
  cluster?: string;
  name?: string;
  screen?: ScreenConfig;
  limits?: ResourceLimits;
}

export interface SessionPoolSummary {
  id: string;
  name: string;
  description?: string;
  system: boolean;
  visibility: 'system' | 'private';
  owner?: PoolOwner | null;
  min: number;
  max: number;
  idle_shutdown_after_ms: number;
  health: string;
  statistics: SessionPoolStatistics;
  session_template?: PoolTemplate | Record<string, any>;
  inserted_at?: string;
  updated_at?: string;
}

export interface SessionPoolFormValues {
  name: string;
  description?: string;
  min: number;
  max: number;
  idle_shutdown_after: number;
  session_template: PoolTemplate & Record<string, any>;
}

// Profile Types
export interface Profile {
  id: string;
  name: string;
  description?: string;
  browser_type: 'chrome' | 'chromium' | 'firefox';
  status: 'active' | 'archived' | 'updating' | 'error';
  has_data: boolean;
  storage_size_bytes?: number;
  version: number;
}

// Form Data Interface (flattened structure for forms)
export interface SessionFormData {
  id?: string;
  name?: string;
  browser_type?: Browser;
  headless?: boolean;
  profile_id?: string;
  screen?: ScreenConfig;
  limits?: ResourceLimits;
  timeout?: number;
  ttl_seconds?: number | null;
  cluster?: string;
  session_pool_id?: string;
}

// API Response Interface (matches API view)
export interface SessionAPI {
  id: string;
  name: string;
  browser_type: Browser;
  status: string;
  live_url?: string;
  stream_url?: string;
  cluster?: string;
  headless?: boolean;
  timeout?: number;
  ttl_seconds?: number | null;
  screen?: ScreenConfig | null;
  limits?: ResourceLimits | null;
}

// Component Props
export interface SessionFormProps {
  session: Partial<SessionFormData>;
  onSessionChange: (session: Partial<SessionFormData>) => void;
  onSubmit: () => void;
  onCancel: () => void;
  isLoading?: boolean;
}

export interface SessionEditProps {
  session: Session;
  errors?: Record<string, string>;
}

/**
 * Convert form data to the backend payload shape.
 */
export function formDataToSession(formData: SessionFormData): Partial<Session> {
  const session: Partial<Session> = {
    name: formData.name,
    browser_type: formData.browser_type ?? 'chrome',
    profile_id: formData.profile_id,
    headless: formData.headless ?? false,
    timeout: formData.timeout,
    ttl_seconds: formData.ttl_seconds ?? null,
    cluster: formData.cluster,
    session_pool_id: formData.session_pool_id,
  };

  if (formData.screen) {
    session.screen = {
      width: formData.screen.width ?? 1920,
      height: formData.screen.height ?? 1080,
      dpi: formData.screen.dpi ?? 96,
      scale: formData.screen.scale ?? 1.0,
    };
  }

  if (formData.limits) {
    session.limits = {
      cpu: formData.limits.cpu,
      memory: formData.limits.memory,
      timeout_minutes: formData.limits.timeout_minutes,
    };
  }

  return session;
}

/**
 * Convert API session to form data and hydrate defaults.
 */
export function sessionToFormData(session: Session): SessionFormData {
  const screen = session.screen || {};
  const limits = session.limits || {};

  return {
    id: session.id,
    name: session.name,
    browser_type: session.browser_type ?? 'chrome',
    profile_id: session.profile_id,
    headless: session.headless ?? false,
    timeout: session.timeout ?? 30,
    ttl_seconds: session.ttl_seconds ?? null,
    cluster: session.cluster,
    session_pool_id: session.session_pool_id,
    screen: {
      width: Number(screen.width ?? 1920),
      height: Number(screen.height ?? 1080),
      dpi: Number(screen.dpi ?? 96),
      scale: Number(screen.scale ?? 1.0),
    },
    limits: {
      cpu: limits.cpu !== undefined ? Number(limits.cpu) : undefined,
      memory: limits.memory,
      timeout_minutes:
        limits.timeout_minutes !== undefined
          ? Number(limits.timeout_minutes)
          : 30,
    },
  };
}
