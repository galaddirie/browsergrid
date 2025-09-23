import React, { useState, useEffect } from 'react';
import { Info, Monitor, User, Cpu, Settings } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { Badge } from '@/components/ui/badge';
import {
  Browser,
  BrowserVersion,
  OperatingSystem,
  Profile,
  ScreenConfig,
  ResourceLimits,
  Session,
  SessionFormProps
} from '@/types';

export function SessionForm({
  session,
  onSessionChange,
  profiles = []
}: Omit<SessionFormProps, 'onSubmit' | 'onCancel' | 'isLoading'> & { profiles?: Profile[] }) {
  const [availableProfiles, setAvailableProfiles] = useState<Profile[]>([]);

  useEffect(() => {
    if (profiles && profiles.length > 0) {
      const browserType = session.browser || 'chrome';
      const filtered = profiles.filter(p =>
        p.browser_type === browserType && p.status === 'active'
      );
      setAvailableProfiles(filtered);

      if (session.profile_id && !filtered.find(p => p.id === session.profile_id)) {
        updateSession({ profile_id: undefined });
      }
    }
  }, [session.browser, profiles]);



  const updateSession = (updates: Partial<Session>) => {
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
      }
    });
  };

  const updateResourceLimits = (limitsUpdates: Partial<ResourceLimits>) => {
    updateSession({
      resource_limits: {
        ...session.resource_limits,
        ...limitsUpdates,
      }
    });
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Browser Configuration */}
      <div className="space-y-4">
        <div className="flex items-center gap-3 pb-2">
          <Monitor className="h-4 w-4 text-gray-500" />
          <div>
            <h3 className="text-sm font-semibold text-gray-900 leading-none">Browser Configuration</h3>
            <p className="text-xs text-gray-500 mt-1">Choose your browser type, version, and operating system</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Browser</Label>
              <Select
                value={session.browser}
                onValueChange={(value: Browser) => updateSession({ browser: value })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
                  <SelectValue placeholder="Select browser" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="chrome">Chrome</SelectItem>
                  <SelectItem value="chromium">Chromium</SelectItem>
                  <SelectItem value="firefox">Firefox</SelectItem>
                  <SelectItem value="edge">Edge</SelectItem>
                  <SelectItem value="webkit">Webkit</SelectItem>
                  <SelectItem value="safari">Safari</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Version</Label>
              <Select
                value={session.version}
                onValueChange={(value: BrowserVersion) => updateSession({ version: value })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
                  <SelectValue placeholder="Select version" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="latest">Latest</SelectItem>
                  <SelectItem value="stable">Stable</SelectItem>
                  <SelectItem value="canary">Canary</SelectItem>
                  <SelectItem value="dev">Dev</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Operating System</Label>
              <Select
                value={session.operating_system}
                onValueChange={(value: OperatingSystem) => updateSession({ operating_system: value })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
                  <SelectValue placeholder="Select OS" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="linux">Linux</SelectItem>
                  <SelectItem value="windows">Windows</SelectItem>
                  <SelectItem value="macos">macOS</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Provider</Label>
              <Select
                value={session.provider || 'docker'}
                onValueChange={(value: string) => updateSession({ provider: value })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
                  <SelectValue placeholder="Select provider" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="docker">Docker</SelectItem>
                  <SelectItem value="local">Local</SelectItem>
                  <SelectItem value="kubernetes">Kubernetes</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 border border-gray-100">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-gray-400"></div>
              <Label htmlFor="headless" className="text-sm text-gray-700 cursor-pointer">Headless mode</Label>
            </div>
            <Switch
              id="headless"
              checked={session.headless}
              onCheckedChange={(checked: boolean) => updateSession({ headless: checked })}
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
            <h3 className="text-sm font-semibold text-gray-900 leading-none">Profile Configuration</h3>
            <p className="text-xs text-gray-500 mt-1">Optionally attach a browser profile to save and restore session state</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Browser Profile (Optional)</Label>
            <Select
              value={session.profile_id || 'none'}
              onValueChange={(value: string) => updateSession({ profile_id: value === 'none' ? undefined : value })}
            >
              <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
                <SelectValue placeholder="Select a profile (optional)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">No profile</SelectItem>
                {availableProfiles.map((profile: Profile) => (
                  <SelectItem key={profile.id} value={profile.id || ''}>
                    <div className="flex items-center justify-between w-full">
                      <span>{profile.name} {profile.has_data && '(has data)'}</span>
                      <Badge variant="secondary" className="ml-2 text-xs bg-gray-100 text-gray-600 border-0">
                        {profile.browser_type}
                      </Badge>
                    </div>
                  </SelectItem>
                ))}
                {availableProfiles.length === 0 && session.browser && (
                  <div className="p-2 text-xs text-gray-500 text-center">
                    No active profiles available for {session.browser}.
                    <a href="/profiles/new" className="text-blue-600 hover:underline ml-1">
                      Create one
                    </a>
                  </div>
                )}
              </SelectContent>
            </Select>
            {session.profile_id && session.profile_id !== 'none' && (
              <div className="mt-4 p-4 rounded-lg bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-100">
                <div className="flex items-start gap-3">
                  <div className="flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 mt-0.5">
                    <Info className="h-3 w-3 text-blue-600" />
                  </div>
                  <div className="flex-1 space-y-1">
                    <div className="text-sm font-medium text-blue-900">
                      {availableProfiles.find((p: Profile) => p.id === session.profile_id)?.name}
                    </div>
                    <div className="text-xs text-blue-700">
                      {availableProfiles.find((p: Profile) => p.id === session.profile_id)?.description || 'No description'}
                    </div>
                    <div className="text-xs text-blue-600">
                      Size: {availableProfiles.find((p: Profile) => p.id === session.profile_id)?.storage_size_bytes
                        ? `${(availableProfiles.find((p: Profile) => p.id === session.profile_id)!.storage_size_bytes! / 1024 / 1024).toFixed(1)} MB`
                        : 'Unknown'
                      }
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
            <h3 className="text-sm font-semibold text-gray-900 leading-none">Screen Configuration</h3>
            <p className="text-xs text-gray-500 mt-1">Set the screen dimensions and display properties</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Width (pixels)</Label>
              <Input
                id="width"
                type="number"
                min="800"
                max="3840"
                value={session.screen?.width || 1920}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => updateScreen({ width: parseInt(e.target.value) || 1920 })}
                className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors"
              />
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Height (pixels)</Label>
              <Input
                id="height"
                type="number"
                min="600"
                max="2160"
                value={session.screen?.height || 1080}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => updateScreen({ height: parseInt(e.target.value) || 1080 })}
                className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">DPI</Label>
              <Select
                value={session.screen?.dpi?.toString() || '96'}
                onValueChange={(value: string) => updateScreen({ dpi: parseInt(value) })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
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
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Scale Factor</Label>
              <Select
                value={session.screen?.scale?.toString() || '1.0'}
                onValueChange={(value: string) => updateScreen({ scale: parseFloat(value) })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
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
            <h3 className="text-sm font-semibold text-gray-900 leading-none">Resource Limits</h3>
            <p className="text-xs text-gray-500 mt-1">Configure CPU, memory, and timeout limits for the session</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">CPU Cores</Label>
              <Input
                id="cpu"
                type="number"
                step="0.5"
                min="0.5"
                max="8"
                placeholder="2.0"
                value={session.resource_limits?.cpu || ''}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => updateResourceLimits({
                  cpu: e.target.value ? parseFloat(e.target.value) : undefined
                })}
                className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors"
              />
            </div>
            <div className="space-y-2">
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Memory</Label>
              <Select
                value={session.resource_limits?.memory || ''}
                onValueChange={(value: string) => updateResourceLimits({ memory: value || undefined })}
              >
                <SelectTrigger className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors">
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
              <Label className="text-xs font-medium text-gray-700 uppercase tracking-wider">Timeout (minutes)</Label>
              <Input
                id="timeout"
                type="number"
                min="5"
                max="480"
                placeholder="30"
                value={session.resource_limits?.timeout_minutes || ''}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => updateResourceLimits({
                  timeout_minutes: e.target.value ? parseInt(e.target.value) : undefined
                })}
                className="h-9 border-gray-200 focus:border-blue-500 focus:ring-blue-500/20 transition-colors"
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
            <h3 className="text-sm font-semibold text-gray-900 leading-none">Advanced Options</h3>
            <p className="text-xs text-gray-500 mt-1">Additional configuration options for the session</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="space-y-4">
            <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 border border-gray-100 hover:bg-gray-100/50 transition-colors">
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-gray-400"></div>
                <Label htmlFor="webhooks" className="text-sm text-gray-700 cursor-pointer">Enable webhooks</Label>
              </div>
              <Switch
                id="webhooks"
                checked={session.webhooks_enabled || false}
                onCheckedChange={(checked: boolean) => updateSession({ webhooks_enabled: checked })}
                className="data-[state=checked]:bg-blue-600"
              />
            </div>

            <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50 border border-gray-100 hover:bg-gray-100/50 transition-colors">
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-gray-400"></div>
                <Label htmlFor="pooled" className="text-sm text-gray-700 cursor-pointer">Use session pooling</Label>
              </div>
              <Switch
                id="pooled"
                checked={session.is_pooled || false}
                onCheckedChange={(checked: boolean) => updateSession({ is_pooled: checked })}
                className="data-[state=checked]:bg-blue-600"
              />
            </div>
          </div>
        </div>
      </div>
    </div>

  );
} 