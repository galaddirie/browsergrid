// Browser and Session Types
export type Browser = 'chrome' | 'chromium' | 'firefox' | 'edge' | 'webkit' | 'safari';
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

// Session Interface
export interface Session {
  id?: string;
  browser?: Browser;
  version?: BrowserVersion;
  operating_system?: OperatingSystem;
  headless?: boolean;
  provider?: string;
  profile_id?: string;
  screen?: ScreenConfig;
  resource_limits?: ResourceLimits;
  webhooks_enabled?: boolean;
  is_pooled?: boolean;
  status?: string;
  created_at?: string;
  live_url?: string;
  expires_at?: string;
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



// Component Props
export interface SessionFormProps {
  session: Partial<Session>;
  onSessionChange: (session: Partial<Session>) => void;
  onSubmit: () => void;
  onCancel: () => void;
  isLoading?: boolean;
}



export interface SessionEditProps {
  session: Session;
  errors?: Record<string, string>;
}
