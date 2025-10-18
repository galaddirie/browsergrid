import { useEffect, useState } from 'react';

import { router } from '@inertiajs/react';
import {
  AlertCircle,
  Clock,
  Droplet,
  Flame,
  Globe,
  Link as LinkIcon,
  Loader2,
  RefreshCw,
  Server,
  ShieldCheck,
} from 'lucide-react';

import Layout from '@/components/Layout';
import { Header } from '@/components/HeaderPortal';
import { PoolForm } from '@/components/pools/PoolForm';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Profile,
  Session,
  SessionPoolFormValues,
  SessionPoolStatistics,
  SessionPoolSummary,
} from '@/types';

interface PoolsShowProps {
  pool: SessionPoolSummary;
  stats: SessionPoolStatistics;
  sessions: Session[];
  profiles: Profile[];
  form: SessionPoolFormValues;
  errors: Record<string, string>;
  claim_result?: {
    session: Session;
    connection: {
      url: string;
      connection: Record<string, any>;
    };
  };
}

const StatusBadge = ({ status }: { status?: string }) => {
  const value = status?.toLowerCase() || 'unknown';

  switch (value) {
    case 'ready':
    case 'running':
    case 'claimed':
      return (
        <Badge className="bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200">
          {status}
        </Badge>
      );
    case 'pending':
    case 'starting':
      return (
        <Badge className="bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200">
          {status}
        </Badge>
      );
    case 'stopped':
    case 'stopping':
      return (
        <Badge className="bg-slate-100 text-slate-800 dark:bg-slate-900 dark:text-slate-200">
          {status}
        </Badge>
      );
    case 'error':
      return (
        <Badge className="bg-rose-100 text-rose-800 dark:bg-rose-900 dark:text-rose-200">
          {status}
        </Badge>
      );
    default:
      return (
        <Badge className="bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-200">
          {status}
        </Badge>
      );
  }
};

const HealthBadge = ({ health }: { health: string }) => {
  const normalized = health?.toLowerCase();
  switch (normalized) {
    case 'healthy':
      return (
        <Badge className="bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200">
          Healthy
        </Badge>
      );
    case 'scaling':
    case 'warming':
      return (
        <Badge className="bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200">
          Warming
        </Badge>
      );
    case 'degraded':
      return (
        <Badge className="bg-rose-100 text-rose-800 dark:bg-rose-900 dark:text-rose-200">
          Degraded
        </Badge>
      );
    default:
      return (
        <Badge className="bg-slate-100 text-slate-800 dark:bg-slate-900 dark:text-slate-200">
          Idle
        </Badge>
      );
  }
};

const formatDateTime = (value?: string) => {
  if (!value) return '—';
  const date = new Date(value);
  return `${date.toLocaleDateString()} ${date.toLocaleTimeString()}`;
};

export default function PoolsShow({
  pool,
  stats,
  sessions,
  profiles,
  form,
  errors,
  claim_result: claimResult,
}: PoolsShowProps) {
  const [isClaiming, setIsClaiming] = useState(false);

  useEffect(() => {
    setIsClaiming(false);
  }, [claimResult?.session?.id]);

  const handleClaim = () => {
    setIsClaiming(true);
    router.post(
      `/pools/${pool.id}/claim`,
      {},
      {
        preserveScroll: true,
        preserveState: true,
        onFinish: () => setIsClaiming(false),
      },
    );
  };

  const handleDelete = () => {
    if (
      window.confirm(
        'Deleting this pool will stop the controller from keeping sessions warm. Continue?',
      )
    ) {
      router.delete(`/pools/${pool.id}`, {
        preserveScroll: true,
      });
    }
  };

  const healthDescription = () => {
    switch (pool.health) {
      case 'healthy':
        return 'Pool is meeting its ready capacity target.';
      case 'warming':
      case 'scaling':
        return 'Pool is warming up sessions to reach target.';
      case 'degraded':
        return 'Some sessions failed and should be investigated.';
      default:
        return 'Pool has no ready sessions yet.';
    }
  };

  return (
    <Layout>
      <Header>
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-4xl font-bold">{pool.name}</h1>
              {pool.system && (
                <Badge variant="outline" className="border-neutral-300 text-xs">
                  System Pool
                </Badge>
              )}
            </div>
            <p className="text-primary/70 mt-2 text-sm">
              {pool.description ||
                'Prewarmed browser sessions with shared configuration.'}
            </p>
            <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-neutral-500">
              <span>Target ready: {pool.target_ready}</span>
              <span>
                Visibility:{' '}
                <Badge
                  variant="outline"
                  className="border-neutral-200 text-xs capitalize"
                >
                  {pool.visibility}
                </Badge>
              </span>
              <span>
                Owner: {pool.owner?.email || (pool.system ? 'Platform' : '—')}
              </span>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              className="text-xs"
              onClick={() => router.reload({ only: ['pool', 'stats', 'sessions'] })}
            >
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
            <Button
              size="sm"
              className="bg-neutral-900 text-xs text-white hover:bg-neutral-800"
              onClick={handleClaim}
              disabled={isClaiming}
            >
              {isClaiming ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Flame className="mr-2 h-4 w-4" />
              )}
              Claim test session
            </Button>
          </div>
        </div>
      </Header>

      <div className="grid gap-6 lg:grid-cols-12">
        <div className="lg:col-span-4 space-y-6">
          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60">
              <CardTitle className="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">
                <ShieldCheck className="h-4 w-4" />
                Health
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 py-6">
              <div className="flex items-center gap-3">
                <HealthBadge health={pool.health} />
                <span className="text-sm text-neutral-600">
                  {healthDescription()}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div className="rounded-lg border border-emerald-200/60 bg-emerald-50 p-3 text-emerald-800">
                  <p className="text-xs uppercase tracking-wide">
                    Ready Sessions
                  </p>
                  <p className="mt-1 text-2xl font-bold">{stats.ready}</p>
                </div>
                <div className="rounded-lg border border-amber-200/60 bg-amber-50 p-3 text-amber-800">
                  <p className="text-xs uppercase tracking-wide">
                    Warming Up
                  </p>
                  <p className="mt-1 text-2xl font-bold">{stats.warming}</p>
                </div>
                <div className="rounded-lg border border-blue-200/60 bg-blue-50 p-3 text-blue-800">
                  <p className="text-xs uppercase tracking-wide">
                    Claimed
                  </p>
                  <p className="mt-1 text-2xl font-bold">{stats.claimed}</p>
                </div>
                <div className="rounded-lg border border-rose-200/60 bg-rose-50 p-3 text-rose-800">
                  <p className="text-xs uppercase tracking-wide">
                    Failed
                  </p>
                  <p className="mt-1 text-2xl font-bold">{stats.errored}</p>
                </div>
              </div>
              {pool.ttl_seconds && (
                <div className="flex items-center gap-2 rounded border border-neutral-200/60 bg-neutral-50 p-3 text-xs text-neutral-600">
                  <Clock className="h-4 w-4 text-neutral-500" />
                  <span>
                    Sessions expire after{' '}
                    <strong>{pool.ttl_seconds} seconds</strong> without an
                    attached client.
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          {claimResult?.connection?.connection && claimResult.session && (
            <Card className="border-blue-200/70">
              <CardHeader className="bg-blue-50/70">
                <CardTitle className="flex items-center gap-2 text-sm font-semibold text-blue-700">
                  <LinkIcon className="h-4 w-4" />
                  Recently Claimed Session
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3 py-5 text-sm text-neutral-700">
                <div className="flex items-center gap-2 text-neutral-900">
                  <Server className="h-4 w-4 text-neutral-500" />
                  <span className="font-mono text-xs">
                    {claimResult.session.id}
                  </span>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wide text-neutral-500">
                    WebSocket URL
                  </p>
                  <code className="mt-1 block break-all rounded bg-neutral-900 p-2 text-xs text-neutral-100">
                    {claimResult.connection.url}
                  </code>
                </div>
              </CardContent>
            </Card>
          )}
        </div>

        <div className="space-y-6 lg:col-span-8">
          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60">
              <CardTitle className="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">
                <Globe className="h-4 w-4" />
                Active Sessions
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>ID</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Claimed</TableHead>
                    <TableHead>Attachment Deadline</TableHead>
                    <TableHead>Created</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {sessions.length === 0 && (
                    <TableRow>
                      <TableCell
                        colSpan={5}
                        className="py-8 text-center text-sm text-neutral-500"
                      >
                        No sessions yet. The controller will warm new sessions
                        shortly.
                      </TableCell>
                    </TableRow>
                  )}
                  {sessions.map(session => (
                    <TableRow key={session.id}>
                      <TableCell className="font-mono text-xs text-neutral-700">
                        {session.id}
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={session.status} />
                      </TableCell>
                      <TableCell className="text-xs text-neutral-600">
                        {formatDateTime(session.claimed_at)}
                      </TableCell>
                      <TableCell className="text-xs text-neutral-600">
                        {formatDateTime(session.attachment_deadline_at)}
                      </TableCell>
                      <TableCell className="text-xs text-neutral-600">
                        {formatDateTime(session.inserted_at)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60">
              <CardTitle className="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-neutral-600">
                <Droplet className="h-4 w-4" />
                Edit Pool Template
              </CardTitle>
            </CardHeader>
            <CardContent className="py-6">
              <PoolForm
                action="update"
                pool={pool}
                initialValues={form}
                profiles={profiles}
                errors={errors}
                onDelete={pool.system ? undefined : handleDelete}
              />
            </CardContent>
          </Card>
        </div>
      </div>

      {stats.errored > 0 && (
        <Card className="mt-6 border-rose-200/70 bg-rose-50/50">
          <CardContent className="flex items-start gap-3 py-4 text-sm text-rose-700">
            <AlertCircle className="mt-0.5 h-4 w-4" />
            <div>
              <p className="font-semibold">Attention recommended</p>
              <p className="mt-1">
                {stats.errored} session
                {stats.errored === 1 ? '' : 's'} failed in this pool. Check
                controller logs and Kubernetes events for more details.
              </p>
            </div>
          </CardContent>
        </Card>
      )}
    </Layout>
  );
}
