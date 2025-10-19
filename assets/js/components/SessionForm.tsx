import { useEffect, useState } from 'react';

import { Cpu, Info, Monitor, Settings, User } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import {
  Browser,
  Profile,
  ResourceLimits,
  ScreenConfig,
  SessionFormData,
  SessionFormProps,
} from '@/types';

export function SessionForm({
  session,
  onSessionChange,
  profiles = [],
}: Omit<SessionFormProps, 'onSubmit' | 'onCancel' | 'isLoading'> & {
  profiles?: Profile[];
}) {
  const [availableProfiles, setAvailableProfiles] = useState<Profile[]>([]);

  useEffect(() => {
    if (profiles && profiles.length > 0) {
      const browserType = session.browser_type || 'chrome';
      const filtered = profiles.filter(
        p => p.browser_type === browserType && p.status === 'active',
      );
      setAvailableProfiles(filtered);

      if (
        session.profile_id &&
        !filtered.find(p => p.id === session.profile_id)
      ) {
        updateSession({ profile_id: undefined });
      }
    }
  }, [session.browser_type, profiles]);

  const updateSession = (updates: Partial<SessionFormData>) => {
    onSessionChange({ ...session, ...updates });
  };

  const updateScreen = (screenUpdates: Partial<ScreenConfig>) => {
    updateSession({
      screen: {
        width: session.screen?.width || 1920,
        height: session.screen?.height || 1080,
        dpi: session.screen?.dpi || 96,
        scale: session.screen?.scale || 1.0,
        ...session.screen,
        ...screenUpdates,
      },
    });
  };

  const updateLimits = (limitsUpdates: Partial<ResourceLimits>) => {
    updateSession({
      limits: {
        ...session.limits,
        ...limitsUpdates,
      },
    });
  };

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      {/* Browser Configuration */}
      <div className="space-y-4">
        <div className="flex items-center gap-3 pb-2">
          <Monitor className="h-4 w-4 text-gray-500" />
          <div>
            <h3 className="text-sm leading-none font-semibold text-gray-900">
              Browser Configuration
            </h3>
            <p className="mt-1 text-xs text-gray-500">
              Choose your browser type and core runtime preferences
            </p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Browser
              </Label>
              <Select
                value={session.browser_type ?? 'chrome'}
                onValueChange={(value: Browser) =>
                  updateSession({ browser_type: value })
                }
              >
                <SelectTrigger className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20">
                  <SelectValue placeholder="Select browser" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="chrome">Chrome</SelectItem>
                  <SelectItem value="chromium">Chromium</SelectItem>
                  <SelectItem value="firefox">Firefox</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Session Name
              </Label>
              <Input
                value={session.name ?? ''}
                onChange={event =>
                  updateSession({ name: event.target.value || undefined })
                }
                placeholder="Optional friendly name"
                className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
              />
            </div>
          </div>

          <div className="flex items-center justify-between rounded-lg border border-gray-100 bg-gray-50 p-3">
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-gray-400"></div>
              <Label
                htmlFor="headless"
                className="cursor-pointer text-sm text-gray-700"
              >
                Headless mode
              </Label>
            </div>
            <Switch
              id="headless"
              checked={!!session.headless}
              onCheckedChange={(checked: boolean) =>
                updateSession({ headless: checked })
              }
              className="data-[state=checked]:bg-blue-600"
            />
          </div>
        </div>
      </div>

      {/* Profile Configuration */}
      <div className="space-y-4">
        <div className="flex items-center gap-3 pb-2">
          <User className="h-4 w-4 text-gray-500" />
          <div>
            <h3 className="text-sm leading-none font-semibold text-gray-900">
              Profile Configuration
            </h3>
            <p className="mt-1 text-xs text-gray-500">
              Optionally attach a browser profile to save and restore session
              state
            </p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
              Browser Profile (Optional)
            </Label>
            <Select
              value={session.profile_id || 'none'}
              onValueChange={(value: string) =>
                updateSession({
                  profile_id: value === 'none' ? undefined : value,
                })
              }
            >
              <SelectTrigger className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20">
                <SelectValue placeholder="Select a profile (optional)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">No profile</SelectItem>
                {availableProfiles.map((profile: Profile) => (
                  <SelectItem key={profile.id} value={profile.id || ''}>
                    <div className="flex w-full items-center justify-between">
                      <span>
                        {profile.name} {profile.has_data && '(has data)'}
                      </span>
                      <Badge
                        variant="secondary"
                        className="ml-2 border-0 bg-gray-100 text-xs text-gray-600"
                      >
                        {profile.browser_type}
                      </Badge>
                    </div>
                  </SelectItem>
                ))}
                {availableProfiles.length === 0 && session.browser_type && (
                  <div className="p-2 text-center text-xs text-gray-500">
                    No active profiles available for {session.browser_type}.
                    <a
                      href="/profiles/new"
                      className="ml-1 text-blue-600 hover:underline"
                    >
                      Create one
                    </a>
                  </div>
                )}
              </SelectContent>
            </Select>
            {session.profile_id && session.profile_id !== 'none' && (
              <div className="mt-4 rounded-lg border border-blue-100 bg-gradient-to-r from-blue-50 to-indigo-50 p-4">
                <div className="flex items-start gap-3">
                  <div className="mt-0.5 flex h-6 w-6 items-center justify-center rounded-full bg-blue-100">
                    <Info className="h-3 w-3 text-blue-600" />
                  </div>
                  <div className="flex-1 space-y-1">
                    <div className="text-sm font-medium text-blue-900">
                      {
                        availableProfiles.find(
                          (p: Profile) => p.id === session.profile_id,
                        )?.name
                      }
                    </div>
                    <div className="text-xs text-blue-700">
                      {availableProfiles.find(
                        (p: Profile) => p.id === session.profile_id,
                      )?.description || 'No description'}
                    </div>
                    <div className="text-xs text-blue-600">
                      Size:{' '}
                      {availableProfiles.find(
                        (p: Profile) => p.id === session.profile_id,
                      )?.storage_size_bytes
                        ? `${(availableProfiles.find((p: Profile) => p.id === session.profile_id)!.storage_size_bytes! / 1024 / 1024).toFixed(1)} MB`
                        : 'Unknown'}
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
      {/* Screen Configuration */}
      <div className="space-y-4">
        <div className="flex items-center gap-3 pb-2">
          <Monitor className="h-4 w-4 text-gray-500" />
          <div>
            <h3 className="text-sm leading-none font-semibold text-gray-900">
              Screen Configuration
            </h3>
            <p className="mt-1 text-xs text-gray-500">
              Set the screen dimensions and display properties
            </p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Width (pixels)
              </Label>
              <Input
                id="width"
                type="number"
                min="800"
                max="3840"
                value={session.screen?.width || 1920}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  updateScreen({ width: parseInt(e.target.value) || 1920 })
                }
                className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
              />
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Height (pixels)
              </Label>
              <Input
                id="height"
                type="number"
                min="600"
                max="2160"
                value={session.screen?.height || 1080}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  updateScreen({ height: parseInt(e.target.value) || 1080 })
                }
                className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                DPI
              </Label>
              <Select
                value={session.screen?.dpi?.toString() || '96'}
                onValueChange={(value: string) =>
                  updateScreen({ dpi: parseInt(value) })
                }
              >
                <SelectTrigger className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="96">96 DPI (Standard)</SelectItem>
                  <SelectItem value="120">120 DPI (High)</SelectItem>
                  <SelectItem value="144">144 DPI (Very High)</SelectItem>
                  <SelectItem value="192">192 DPI (Ultra High)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Scale Factor
              </Label>
              <Select
                value={session.screen?.scale?.toString() || '1.0'}
                onValueChange={(value: string) =>
                  updateScreen({ scale: parseFloat(value) })
                }
              >
                <SelectTrigger className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="1.0">1.0x (Normal)</SelectItem>
                  <SelectItem value="1.25">1.25x</SelectItem>
                  <SelectItem value="1.5">1.5x</SelectItem>
                  <SelectItem value="2.0">2.0x (Retina)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
      </div>

      {/* Resource Limits */}
      <div className="space-y-4">
        <div className="flex items-center gap-3 pb-2">
          <Cpu className="h-4 w-4 text-gray-500" />
          <div>
            <h3 className="text-sm leading-none font-semibold text-gray-900">
              Resource Limits
            </h3>
            <p className="mt-1 text-xs text-gray-500">
              Configure CPU, memory, and timeout limits for the session
            </p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                CPU Cores
              </Label>
              <Input
                id="cpu"
                type="number"
                step="0.5"
                min="0.5"
                max="8"
                placeholder="2.0"
                value={session.limits?.cpu ?? ''}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  updateLimits({
                    cpu: e.target.value
                      ? parseFloat(e.target.value)
                      : undefined,
                  })
                }
                className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
              />
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Memory
              </Label>
              <Select
                value={session.limits?.memory || ''}
                onValueChange={(value: string) =>
                  updateLimits({ memory: value || undefined })
                }
              >
                <SelectTrigger className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20">
                  <SelectValue placeholder="Select memory" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="512MB">512 MB</SelectItem>
                  <SelectItem value="1GB">1 GB</SelectItem>
                  <SelectItem value="2GB">2 GB</SelectItem>
                  <SelectItem value="4GB">4 GB</SelectItem>
                  <SelectItem value="8GB">8 GB</SelectItem>
                  <SelectItem value="16GB">16 GB</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
                Timeout (minutes)
              </Label>
              <Input
                id="timeout"
                type="number"
                min="5"
                max="480"
                placeholder="30"
                value={session.limits?.timeout_minutes ?? ''}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  updateLimits({
                    timeout_minutes: e.target.value
                      ? parseInt(e.target.value)
                      : undefined,
                  })
                }
                className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Advanced Options */}
      <div className="space-y-4">
        <div className="flex items-center gap-3 pb-2">
          <Settings className="h-4 w-4 text-gray-500" />
          <div>
            <h3 className="text-sm leading-none font-semibold text-gray-900">
              Advanced Options
            </h3>
            <p className="mt-1 text-xs text-gray-500">
              Additional configuration options for the session
            </p>
          </div>
        </div>
        <div className="grid gap-4 md:grid-cols-3">
          <div className="space-y-2">
            <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
              Session Timeout (minutes)
            </Label>
            <Input
              id="session-timeout"
              type="number"
              min={1}
              value={session.timeout ?? 30}
              onChange={event =>
                updateSession({
                  timeout:
                    event.target.value === ''
                      ? undefined
                      : Number.parseInt(event.target.value, 10),
                })
              }
              className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
            />
          </div>
          <div className="space-y-2">
            <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
              TTL (seconds, optional)
            </Label>
            <Input
              id="session-ttl"
              type="number"
              min={0}
              value={session.ttl_seconds ?? ''}
              onChange={event =>
                updateSession({
                  ttl_seconds:
                    event.target.value === ''
                      ? null
                      : Number.parseInt(event.target.value, 10),
                })
              }
              placeholder="Default from pool/runtime"
              className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
            />
          </div>
          <div className="space-y-2">
            <Label className="text-xs font-medium tracking-wider text-gray-700 uppercase">
              Cluster (optional)
            </Label>
            <Input
              id="session-cluster"
              value={session.cluster ?? ''}
              onChange={event =>
                updateSession({
                  cluster: event.target.value || undefined,
                })
              }
              placeholder="Override the default cluster"
              className="h-9 border-gray-200 transition-colors focus:border-blue-500 focus:ring-blue-500/20"
            />
          </div>
        </div>
      </div>
    </div>
  );
}
