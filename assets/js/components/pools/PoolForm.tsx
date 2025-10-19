import { useEffect, useMemo, useState } from 'react';

import { router } from '@inertiajs/react';
import {
  Braces,
  Clock,
  Cpu,
  Layers,
  Monitor,
  Save,
  Shield,
  Trash2,
} from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
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
import { Textarea } from '@/components/ui/textarea';
import {
  PoolTemplate,
  Profile,
  SessionPoolFormValues,
  SessionPoolSummary,
} from '@/types';

interface PoolFormProps {
  action: 'create' | 'update';
  pool?: SessionPoolSummary | null;
  initialValues: SessionPoolFormValues;
  profiles?: Profile[];
  errors?: Record<string, string>;
  isSubmitting?: boolean;
  onSubmit?: (values: SessionPoolFormValues) => void;
  onDelete?: () => void;
}

const defaultTemplate: PoolTemplate & Record<string, any> = {
  browser_type: 'chrome',
  headless: false,
  timeout: 30,
  ttl_seconds: null,
  screen: { width: 1920, height: 1080, dpi: 96, scale: 1.0 },
  limits: { cpu: null, memory: null, timeout_minutes: 30 },
};

const IDLE_DEFAULT_MS = 600_000;

export function PoolForm({
  action,
  pool,
  initialValues,
  profiles = [],
  errors = {},
  isSubmitting = false,
  onSubmit,
  onDelete,
}: PoolFormProps) {
  const [form, setForm] = useState<SessionPoolFormValues>({
    ...initialValues,
    min: initialValues.min ?? 1,
    max: initialValues.max ?? 0,
    idle_shutdown_after: initialValues.idle_shutdown_after ?? IDLE_DEFAULT_MS,
    session_template: {
      ...defaultTemplate,
      ...(initialValues.session_template || {}),
      screen: {
        ...defaultTemplate.screen,
        ...(initialValues.session_template?.screen || {}),
      },
      limits: {
        ...defaultTemplate.limits,
        ...(initialValues.session_template?.limits || {}),
      },
    },
  });

  useEffect(() => {
    setForm({
      ...initialValues,
      min: initialValues.min ?? 1,
      max: initialValues.max ?? 0,
      idle_shutdown_after: initialValues.idle_shutdown_after ?? IDLE_DEFAULT_MS,
      session_template: {
        ...defaultTemplate,
        ...(initialValues.session_template || {}),
        screen: {
          ...defaultTemplate.screen,
          ...(initialValues.session_template?.screen || {}),
        },
        limits: {
          ...defaultTemplate.limits,
          ...(initialValues.session_template?.limits || {}),
        },
      },
    });
  }, [initialValues.session_template, initialValues.min, initialValues.max, initialValues.idle_shutdown_after, initialValues.name, initialValues.description]);

  const idleShutdownMinutes = Math.round((form.idle_shutdown_after ?? IDLE_DEFAULT_MS) / 60000);

  const handleChange = (
    field: keyof SessionPoolFormValues,
    value: SessionPoolFormValues[keyof SessionPoolFormValues],
  ) => {
    setForm(previous => ({
      ...previous,
      [field]: value,
    }));
  };

  const handleIdleMinutesChange = (value: string) => {
    if (value === '') {
      handleChange('idle_shutdown_after', 0);
      return;
    }

    const parsed = Number.parseInt(value, 10);

    if (Number.isNaN(parsed) || parsed < 0) {
      handleChange('idle_shutdown_after', 0);
      return;
    }

    handleChange('idle_shutdown_after', parsed * 60_000);
  };

  const updateTemplate = (updates: Partial<PoolTemplate>) => {
    setForm(previous => ({
      ...previous,
      session_template: {
        ...previous.session_template,
        ...updates,
        screen: updates.screen
          ? {
              ...previous.session_template.screen,
              ...updates.screen,
            }
          : previous.session_template.screen,
        limits: updates.limits
          ? {
              ...previous.session_template.limits,
              ...updates.limits,
            }
          : previous.session_template.limits,
      },
    }));
  };

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    if (onSubmit) {
      onSubmit(form);
      return;
    }

    if (action === 'create') {
      router.post(
        '/pools',
        { pool: form },
        {
          preserveScroll: true,
          preserveState: false,
        },
      );
    } else if (action === 'update' && pool?.id) {
      router.put(
        `/pools/${pool.id}`,
        { pool: form },
        {
          preserveScroll: true,
          preserveState: false,
        },
      );
    }
  };

  const templatePreview = useMemo(() => {
    const template = form.session_template || {};
    const screen = template.screen || {};
    const limits = template.limits || {};

    return [
      `Browser: ${template.browser_type || 'chrome'} (${template.headless ? 'headless' : 'headed'})`,
      template.profile_id ? `Profile: ${profiles.find(p => p.id === template.profile_id)?.name || template.profile_id}` : 'Profile: none',
      `Timeout: ${template.timeout ?? 30} minutes`,
      template.ttl_seconds ? `TTL: ${template.ttl_seconds} seconds` : 'TTL: default controller value',
      `Screen: ${screen.width}x${screen.height} @${screen.dpi} DPI`,
      `CPU: ${limits.cpu ?? 'default'} cores, Memory: ${limits.memory ?? 'default'}`,
      template.cluster ? `Cluster: ${template.cluster}` : 'Cluster: default',
    ];
  }, [form.session_template, profiles]);

  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="border-neutral-200/60">
          <CardHeader className="bg-neutral-50/60">
            <CardTitle className="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">
              <Shield className="h-4 w-4" />
              Pool Configuration
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 py-6">
            <div className="space-y-2">
              <Label htmlFor="pool-name">
                Pool Name <span className="text-destructive">*</span>
              </Label>
              <Input
                id="pool-name"
                value={form.name}
                onChange={event => handleChange('name', event.target.value)}
                placeholder="e.g. chrome-regression, firefox-debug"
                className={errors.name ? 'border-destructive' : ''}
              />
              {errors.name && (
                <p className="text-sm text-destructive">{errors.name}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="pool-description">Description</Label>
              <Textarea
                id="pool-description"
                value={form.description || ''}
                onChange={event => handleChange('description', event.target.value)}
                placeholder="Share context with your team about what this pool is optimised for."
                rows={3}
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="pool-min">
                  Minimum Ready Sessions{' '}
                  <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="pool-min"
                  type="number"
                  min={0}
                  value={form.min}
                  onChange={event =>
                    handleChange(
                      'min',
                      Number.parseInt(event.target.value || '0', 10),
                    )
                  }
                  className={errors.min_ready ? 'border-destructive' : ''}
                />
                {errors.min_ready && (
                  <p className="text-sm text-destructive">{errors.min_ready}</p>
                )}
              </div>

              <div className="space-y-2">
                <Label htmlFor="pool-max">Maximum Ready Sessions (0 = unlimited)</Label>
                <Input
                  id="pool-max"
                  type="number"
                  min={0}
                  value={form.max}
                  onChange={event =>
                    handleChange(
                      'max',
                      Number.parseInt(event.target.value || '0', 10),
                    )
                  }
                  className={errors.max_ready ? 'border-destructive' : ''}
                />
                {errors.max_ready && (
                  <p className="text-sm text-destructive">{errors.max_ready}</p>
                )}
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="pool-idle">Idle Shutdown After (minutes)</Label>
              <Input
                id="pool-idle"
                type="number"
                min={0}
                value={idleShutdownMinutes}
                onChange={event => handleIdleMinutesChange(event.target.value)}
                className={errors.idle_shutdown_after_ms ? 'border-destructive' : ''}
              />
              {errors.idle_shutdown_after_ms && (
                <p className="text-sm text-destructive">
                  {errors.idle_shutdown_after_ms}
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        <Card className="border-neutral-200/60">
          <CardHeader className="bg-neutral-50/60">
            <CardTitle className="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">
              <Braces className="h-4 w-4" />
              Session Template
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 py-6">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label>Browser Type</Label>
                <Select
                  value={form.session_template.browser_type || 'chrome'}
                  onValueChange={value =>
                    updateTemplate({ browser_type: value as PoolTemplate['browser_type'] })
                  }
                >
                  <SelectTrigger id="template-browser">
                    <SelectValue placeholder="Choose browser" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="chrome">Chrome</SelectItem>
                    <SelectItem value="chromium">Chromium</SelectItem>
                    <SelectItem value="firefox">Firefox</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Profile</Label>
                <Select
                  value={form.session_template.profile_id || 'none'}
                  onValueChange={value =>
                    updateTemplate({
                      profile_id: value === 'none' ? undefined : value,
                    })
                  }
                >
                  <SelectTrigger id="template-profile">
                    <SelectValue placeholder="Optional profile" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">No profile</SelectItem>
                    {profiles.map(profile => (
                      <SelectItem key={profile.id} value={profile.id}>
                        {profile.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="flex items-center justify-between rounded-lg border border-neutral-200/60 bg-neutral-50 px-4 py-3">
              <div className="flex items-center gap-2">
                <Layers className="h-4 w-4 text-neutral-500" />
                <span className="text-sm text-neutral-700">Headless mode</span>
              </div>
              <Switch
                checked={!!form.session_template.headless}
                onCheckedChange={checked => updateTemplate({ headless: checked })}
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="template-timeout">Timeout (minutes)</Label>
                <Input
                  id="template-timeout"
                  type="number"
                  min={1}
                  value={form.session_template.timeout ?? 30}
                  onChange={event =>
                    updateTemplate({
                      timeout: Number.parseInt(event.target.value || '30', 10),
                    })
                  }
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="template-cluster">Cluster</Label>
                <Input
                  id="template-cluster"
                  value={form.session_template.cluster || ''}
                  onChange={event =>
                    updateTemplate({ cluster: event.target.value || undefined })
                  }
                  placeholder="Optional cluster hint"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="template-ttl">TTL (seconds)</Label>
                <Input
                  id="template-ttl"
                  type="number"
                  min={0}
                  value={
                    form.session_template.ttl_seconds === null ||
                    form.session_template.ttl_seconds === undefined
                      ? ''
                      : form.session_template.ttl_seconds
                  }
                  onChange={event =>
                    updateTemplate({
                      ttl_seconds:
                        event.target.value === ''
                          ? null
                          : Number.parseInt(event.target.value || '0', 10),
                    })
                  }
                />
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label>Screen Width</Label>
                <Input
                  type="number"
                  min={320}
                  value={form.session_template.screen?.width ?? 1920}
                  onChange={event =>
                    updateTemplate({
                      screen: {
                        ...(form.session_template.screen || {}),
                        width: Number.parseInt(event.target.value || '1920', 10),
                      },
                    })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label>Screen Height</Label>
                <Input
                  type="number"
                  min={240}
                  value={form.session_template.screen?.height ?? 1080}
                  onChange={event =>
                    updateTemplate({
                      screen: {
                        ...(form.session_template.screen || {}),
                        height: Number.parseInt(event.target.value || '1080', 10),
                      },
                    })
                  }
                />
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label>CPU (cores)</Label>
                <Input
                  type="number"
                  min={0}
                  value={
                    form.session_template.limits?.cpu === null ||
                    form.session_template.limits?.cpu === undefined
                      ? ''
                      : form.session_template.limits?.cpu
                  }
                  onChange={event =>
                    updateTemplate({
                      limits: {
                        ...(form.session_template.limits || {}),
                        cpu:
                          event.target.value === ''
                            ? null
                            : Number.parseFloat(event.target.value),
                      },
                    })
                  }
                  placeholder="Auto"
                />
              </div>
              <div className="space-y-2">
                <Label>Memory</Label>
                <Input
                  value={form.session_template.limits?.memory || ''}
                  onChange={event =>
                    updateTemplate({
                      limits: {
                        ...(form.session_template.limits || {}),
                        memory: event.target.value || null,
                      },
                    })
                  }
                  placeholder="e.g. 2Gi"
                />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card className="border-neutral-200/60">
        <CardHeader className="flex flex-row items-center justify-between bg-neutral-50/60">
          <div>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">
              <Monitor className="h-4 w-4" />
              Template Preview
            </CardTitle>
            <p className="text-neutral-500 mt-1 text-sm">
              This is how the controller will launch sessions for this pool.
            </p>
          </div>
          {action === 'update' && onDelete && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="text-destructive hover:bg-destructive/10"
              onClick={onDelete}
            >
              <Trash2 className="mr-1.5 h-4 w-4" />
              Delete Pool
            </Button>
          )}
        </CardHeader>
        <CardContent className="grid gap-6 py-6 md:grid-cols-2">
          <div className="space-y-4">
            <div className="flex items-center gap-3 rounded-lg border border-neutral-200/60 bg-white p-4 shadow-sm">
              <Clock className="h-5 w-5 text-neutral-500" />
              <div>
                <p className="text-sm font-semibold text-neutral-800">
                  Always-on capacity
                </p>
                <p className="text-xs text-neutral-500">
                  Pool keeps at least {form.min} sessions warm
                  {(form.max ?? 0) > 0 ? ` (max ${form.max ?? 0})` : ' (no upper limit)'} with{' '}
                  {form.session_template.browser_type || 'chrome'} ready to go.
                </p>
              </div>
            </div>

            <div className="rounded-lg border border-neutral-200/60 bg-white p-4 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">
                Template JSON
              </p>
              <pre className="mt-2 max-h-48 overflow-auto rounded bg-neutral-900 p-3 text-xs text-neutral-100">
                {JSON.stringify(form.session_template, null, 2)}
              </pre>
            </div>
          </div>

          <div className="space-y-4">
            <div className="rounded-lg border border-neutral-200/60 bg-white p-4 shadow-sm">
              <div className="flex items-center gap-2 text-sm font-semibold text-neutral-700">
                <Cpu className="h-4 w-4 text-neutral-500" />
                Runtime Profile
              </div>
              <ul className="mt-3 space-y-2 text-sm text-neutral-600">
                {templatePreview.map(line => (
                  <li key={line}>• {line}</li>
                ))}
              </ul>
            </div>

            {Object.keys(errors).length > 0 && (
              <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-4 text-sm text-destructive">
                <p className="font-semibold">Please resolve the following:</p>
                <ul className="mt-2 list-disc space-y-1 pl-5">
                  {Object.entries(errors).map(([field, message]) => (
                    <li key={field}>
                      <span className="font-medium">{field}:</span> {message}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      <div className="flex items-center justify-end gap-2">
        <Button
          type="submit"
          className="bg-neutral-900 text-white hover:bg-neutral-800"
          disabled={isSubmitting}
        >
          <Save className="mr-2 h-4 w-4" />
          {action === 'create' ? 'Create Pool' : 'Save Changes'}
        </Button>
      </div>
    </form>
  );
}
