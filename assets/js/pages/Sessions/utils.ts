import { Browser, Session, SessionFormData } from '@/types';

const TERMINAL_SESSION_STATUS_VALUES = [
  'completed',
  'failed',
  'expired',
  'crashed',
  'timed_out',
  'terminated',
  'stopped',
];

const STATUS_TONES: Record<string, string> = {
  available: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  ready: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  running: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  active: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  claimed: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
  starting: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
  failed: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
  crashed: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
  terminated: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
  idle: 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200',
  completed: 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200',
};

const dateFormatter = new Intl.DateTimeFormat(undefined, {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
});

const timeFormatter = new Intl.DateTimeFormat(undefined, {
  hour: '2-digit',
  minute: '2-digit',
});

export function isTerminalStatus(status?: string | null): boolean {
  if (!status) {
    return false;
  }

  return TERMINAL_SESSION_STATUS_VALUES.includes(status.toLowerCase());
}

export function sessionStatusTone(status?: string | null): string {
  const normalized = status?.toLowerCase() ?? 'unknown';
  return STATUS_TONES[normalized] ?? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
}

export function formatDate(value?: string | null): string {
  if (!value) {
    return '—';
  }

  return dateFormatter.format(new Date(value));
}

export function formatTime(value?: string | null): string {
  if (!value) {
    return '';
  }

  return timeFormatter.format(new Date(value));
}

export function formatDateTime(value?: string | null): string {
  if (!value) {
    return '—';
  }

  return `${formatDate(value)} ${formatTime(value)}`.trim();
}

export function getCsrfToken(): string {
  if (typeof document === 'undefined') {
    return '';
  }

  return (
    document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content') ?? ''
  );
}

export async function fetchWithCsrf(
  input: RequestInfo | URL,
  init: RequestInit = {},
) {
  const headers = new Headers(init.headers ?? {});
  const csrfToken = getCsrfToken();

  if (csrfToken && !headers.has('X-CSRF-Token')) {
    headers.set('X-CSRF-Token', csrfToken);
  }

  if (!headers.has('Accept')) {
    headers.set('Accept', 'application/json');
  }

  const isFormDataBody = init.body instanceof FormData;
  if (!isFormDataBody && init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  return fetch(input, {
    ...init,
    headers,
  });
}

export function buildSessionFormData(session: Partial<Session>): FormData {
  const formData = new FormData();

  const appendIfPresent = (key: string, value: unknown) => {
    if (value === undefined || value === null) {
      return;
    }

    formData.append(key, String(value));
  };

  appendIfPresent('session[name]', session.name);
  appendIfPresent('session[browser_type]', session.browser_type ?? 'chrome');
  appendIfPresent('session[profile_id]', session.profile_id);
  if (session.headless !== undefined) {
    appendIfPresent('session[headless]', session.headless ? 'true' : 'false');
  }
  appendIfPresent('session[timeout]', session.timeout);
  if (session.ttl_seconds !== undefined && session.ttl_seconds !== null) {
    appendIfPresent('session[ttl_seconds]', session.ttl_seconds);
  }
  appendIfPresent('session[cluster]', session.cluster);
  appendIfPresent('session[session_pool_id]', session.session_pool_id);

  if (session.screen) {
    appendIfPresent('session[screen][width]', session.screen.width);
    appendIfPresent('session[screen][height]', session.screen.height);
    appendIfPresent('session[screen][dpi]', session.screen.dpi);
    appendIfPresent('session[screen][scale]', session.screen.scale);
  }

  if (session.limits) {
    appendIfPresent('session[limits][cpu]', session.limits.cpu);
    appendIfPresent('session[limits][memory]', session.limits.memory);
    appendIfPresent('session[limits][timeout_minutes]', session.limits.timeout_minutes);
  }

  return formData;
}

export function buildDefaultSessionForm(
  defaultBrowser?: Browser,
): Partial<SessionFormData> {
  return {
    browser_type: defaultBrowser ?? 'chrome',
    headless: false,
    timeout: 30,
    ttl_seconds: null,
    screen: {
      width: 1920,
      height: 1080,
      dpi: 96,
      scale: 1.0,
    },
    limits: {
      cpu: 2.0,
      memory: '4GB',
      timeout_minutes: 30,
    },
  };
}
