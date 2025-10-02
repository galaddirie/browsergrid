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
    version?: BrowserVersion;
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
  headless?: boolean;
  profile_id?: string;
  screen?: ScreenConfig;
  resource_limits?: ResourceLimits;
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
    version?: BrowserVersion;
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

/**
 * Convert form data to API payload
 * Flattens nested structures into options map
 */
export function formDataToSession(formData: SessionFormData): Partial<Session> {
  const session: Partial<Session> = {
    name: formData.name,
    browser_type: formData.browser_type,
    profile_id: formData.profile_id,
    options: {}
  };

  // Simple fields that go into options
  const simpleOptions = {
    version: formData.version,
    headless: formData.headless,

  };

  // Add simple options (filter out undefined)
  Object.entries(simpleOptions).forEach(([key, value]) => {
    if (value !== undefined) {
      session.options![key] = value;
    }
  });

  // Flatten screen config into options
  if (formData.screen) {
    session.options!.screen_width = formData.screen.width;
    session.options!.screen_height = formData.screen.height;
    session.options!.screen_dpi = formData.screen.dpi;
    session.options!.screen_scale = formData.screen.scale;
  }

  // Flatten resource limits into options
  if (formData.resource_limits) {
    if (formData.resource_limits.cpu !== undefined) {
      session.options!.cpu_cores = formData.resource_limits.cpu;
    }
    if (formData.resource_limits.memory) {
      session.options!.memory_limit = formData.resource_limits.memory;
    }
    if (formData.resource_limits.timeout_minutes !== undefined) {
      session.options!.timeout = formData.resource_limits.timeout_minutes;
    }
  }

  return session;
}

/**
 * Convert API session to form data
 * Extracts options back into nested structure
 */
export function sessionToFormData(session: Session): SessionFormData {
  const options = session.options || {};

  return {
    name: session.name,
    browser_type: session.browser_type,
    profile_id: session.profile_id,

    // Extract simple options
    version: options.version as BrowserVersion,
    headless: options.headless,

    // Reconstruct screen config
    screen: {
      width: options.screen_width || 1920,
      height: options.screen_height || 1080,
      dpi: options.screen_dpi || 96,
      scale: options.screen_scale || 1.0
    },

    // Reconstruct resource limits
    resource_limits: {
      cpu: options.cpu_cores,
      memory: options.memory_limit,
      timeout_minutes: options.timeout || 30
    }
  };
}
