// Browser and Session Types
export type Browser = 'chrome' | 'chromium' | 'firefox';
export type BrowserVersion = 'latest' | 'stable' | 'canary' | 'dev';
export type OperatingSystem = 'linux' | 'windows' | 'macos';

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
  browser_type?: Browser;
  status?: string;
  options?: {
    headless?: boolean;
    is_pooled?: boolean;
    operating_system?: OperatingSystem;
    provider?: string;
    version?: BrowserVersion;
    webhooks_enabled?: boolean;
    screen_width?: number;
    screen_height?: number;
    screen_dpi?: number;
    screen_scale?: number;
    cpu_cores?: number;
    memory_limit?: string;
    timeout?: number;
    profile_enabled?: boolean;
    [key: string]: any; // Allow additional options
  };
  cluster?: string;
  profile_id?: string;
  profile_snapshot_created?: boolean;
  inserted_at?: string;
  updated_at?: string;
  // Optional profile relation (when preloaded)
  profile?: Profile;
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
  version?: BrowserVersion;
  operating_system?: OperatingSystem;
  headless?: boolean;
  provider?: string;
  profile_id?: string;
  screen?: ScreenConfig;
  resource_limits?: ResourceLimits;
  webhooks_enabled?: boolean;
  is_pooled?: boolean;
}

// API Response Interface (matches API view)
export interface SessionAPI {
  id: string;
  name: string;
  browser_type: Browser;
  status: string;
  cluster?: string;
  options: {
    headless?: boolean;
    is_pooled?: boolean;
    operating_system?: OperatingSystem;
    provider?: string;
    version?: BrowserVersion;
    webhooks_enabled?: boolean;
    screen_width?: number;
    screen_height?: number;
    screen_dpi?: number;
    screen_scale?: number;
    cpu_cores?: number;
    memory_limit?: string;
    timeout?: number;
    profile_enabled?: boolean;
    [key: string]: any;
  };
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

// Utility functions for converting between Session and SessionFormData
export function sessionToFormData(session: Session): SessionFormData {
  const options = session.options || {};

  return {
    id: session.id,
    name: session.name,
    browser_type: session.browser_type,
    version: options.version as BrowserVersion,
    operating_system: options.operating_system as OperatingSystem,
    headless: options.headless,
    provider: options.provider,
    profile_id: session.profile_id || undefined,
    screen: options.screen_width ? {
      width: options.screen_width,
      height: options.screen_height || 1080,
      dpi: options.screen_dpi || 96,
      scale: options.screen_scale || 1.0
    } : undefined,
    resource_limits: (options.cpu_cores !== undefined || options.memory_limit !== undefined || options.timeout !== undefined) ? {
      cpu: options.cpu_cores,
      memory: options.memory_limit,
      timeout_minutes: options.timeout
    } : undefined,
    webhooks_enabled: options.webhooks_enabled,
    is_pooled: options.is_pooled
  };
}

export function formDataToSession(formData: SessionFormData): Partial<Session> {
  const session: Partial<Session> = {
    name: formData.name,
    browser_type: formData.browser_type,
    profile_id: formData.profile_id,
    options: {}
  };

  const options: any = {};

  if (formData.version) options.version = formData.version;
  if (formData.operating_system) options.operating_system = formData.operating_system;
  if (formData.headless !== undefined) options.headless = formData.headless;
  if (formData.provider) options.provider = formData.provider;
  if (formData.webhooks_enabled !== undefined) options.webhooks_enabled = formData.webhooks_enabled;
  if (formData.is_pooled !== undefined) options.is_pooled = formData.is_pooled;

  if (formData.screen) {
    options.screen_width = formData.screen.width;
    options.screen_height = formData.screen.height;
    options.screen_dpi = formData.screen.dpi;
    options.screen_scale = formData.screen.scale;
  }

  if (formData.resource_limits) {
    if (formData.resource_limits.cpu !== undefined) options.cpu_cores = formData.resource_limits.cpu;
    if (formData.resource_limits.memory) options.memory_limit = formData.resource_limits.memory;
    if (formData.resource_limits.timeout_minutes !== undefined) options.timeout = formData.resource_limits.timeout_minutes;
  }

  session.options = options;
  return session;
}
