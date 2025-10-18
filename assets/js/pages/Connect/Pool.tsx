import { useCallback, useMemo } from 'react';

import { router } from '@inertiajs/react';
import { Activity, Plug, RefreshCw } from 'lucide-react';

import { Header } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
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

type PoolSnapshot = {
  enabled: boolean;
  online: boolean;
  pool_size: number;
  claim_timeout_ms: number;
  session_prefix: string | null;
  browser_type: string | null;
  counts: Record<string, number>;
  idle_queue: string[];
  claims: { token: string; token_tail: string; session_id: string }[];
  sessions: Array<{
    id: string;
    status: string;
    inserted_at: string | null;
    claimed_by: string | null;
    claimed_by_label: string | null;
    claimed_at: string | null;
    claim_expires_at: string | null;
    endpoint: Record<string, unknown> | null;
    metadata: Record<string, unknown>;
    ws_attached: boolean;
    connected: boolean;
    in_idle_queue: boolean;
  }>;
  fetched_at: string | null;
};

export default function ConnectPool({
  pool,
}: {
  pool: PoolSnapshot;
}): JSX.Element {
  const statusCards = useMemo(() => {
    const entries = Object.entries(pool.counts ?? {});

    if (entries.length === 0) {
      return [];
    }

    return entries.map(([status, count]) => ({
      status,
      count,
    }));
  }, [pool.counts]);

  const handleRefresh = useCallback(() => {
    router.reload({ only: ['pool'] });
  }, []);

  const statusBadgeClass = useCallback((status: string) => {
    switch (status) {
      case 'connected':
        return 'bg-emerald-100 text-emerald-900 dark:bg-emerald-400/20 dark:text-emerald-100';
      case 'claimed':
        return 'bg-amber-100 text-amber-900 dark:bg-amber-400/20 dark:text-amber-100';
      case 'idle':
        return 'bg-blue-100 text-blue-900 dark:bg-blue-400/20 dark:text-blue-100';
      case 'starting':
        return 'bg-slate-100 text-slate-900 dark:bg-slate-400/20 dark:text-slate-100';
      default:
        return 'bg-muted text-foreground';
    }
  }, []);

  const formattedFetchedAt = pool.fetched_at
    ? new Date(pool.fetched_at).toLocaleString()
    : null;

  return (
    <Layout>
      <Header>
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="mb-2 flex items-center gap-2 text-4xl font-bold">
              <Plug className="h-8 w-8 text-blue-500" />
              Connect Pool
            </h1>
            <p className="text-primary/70 max-w-3xl text-sm">
              Inspect the pre-warmed browser pool backing the connect endpoint.
              Track idle capacity, claims, and WebSocket attachments for fast
              debugging.
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" onClick={handleRefresh}>
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
          </div>
        </div>
      </Header>

      <div className="space-y-6">
        {!pool.enabled && (
          <Alert className="border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-500/10 dark:text-amber-100">
            <AlertTitle>Connect pool disabled</AlertTitle>
            <AlertDescription>
              Enable CONNECT_ENABLED or Browsergrid.Connect supervisor to warm
              sessions in advance.
            </AlertDescription>
          </Alert>
        )}

        {pool.enabled && !pool.online && (
          <Alert className="border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-500/10 dark:text-amber-100">
            <AlertTitle>Pool supervisor offline</AlertTitle>
            <AlertDescription>
              The idle pool process is not currently running. Verify the
              Browsergrid.Connect.Supervisor is started on this node.
            </AlertDescription>
          </Alert>
        )}

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <div>
              <CardTitle className="text-lg font-semibold">
                Pool Configuration
              </CardTitle>
              <p className="text-muted-foreground text-sm">
                Environment-sourced settings and live readiness.
              </p>
            </div>
            <Badge
              variant={pool.enabled && pool.online ? 'default' : 'secondary'}
              className={`flex items-center gap-2 ${pool.enabled && pool.online ? 'bg-emerald-500 text-white hover:bg-emerald-500/90' : ''}`}
            >
              <Activity className="h-4 w-4" />
              {pool.enabled
                ? pool.online
                  ? 'Online'
                  : 'Configured / offline'
                : 'Disabled'}
            </Badge>
          </CardHeader>
          <CardContent className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Metric label="Desired pool size" value={pool.pool_size} />
            <Metric
              label="Claim timeout"
              value={`${(pool.claim_timeout_ms / 1000).toFixed(1)}s`}
            />
            <Metric label="Browser type" value={pool.browser_type ?? '—'} />
            <Metric label="Session prefix" value={pool.session_prefix ?? '—'} />
          </CardContent>
          {formattedFetchedAt && (
            <CardContent className="text-muted-foreground -mt-4 text-right text-xs">
              Snapshot captured {formattedFetchedAt}
            </CardContent>
          )}
        </Card>

        {statusCards.length > 0 && (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {statusCards.map(({ status, count }) => (
              <Card key={status}>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm capitalize text-muted-foreground">
                    {status}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{count}</div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        <Card>
          <CardHeader>
            <CardTitle className="text-lg font-semibold">
              Active Claims
            </CardTitle>
          </CardHeader>
          <CardContent>
            {pool.claims.length === 0 ? (
              <p className="text-muted-foreground text-sm">
                No outstanding claims.
              </p>
            ) : (
              <div className="space-y-2">
                {pool.claims.map((claim) => (
                  <div
                    key={`${claim.token}:${claim.session_id}`}
                    className="flex flex-col gap-1 rounded border p-3 md:flex-row md:items-center md:justify-between"
                  >
                    <div className="font-mono text-xs text-muted-foreground">
                      Token: {claim.token_tail}
                    </div>
                    <div className="font-mono text-xs text-muted-foreground">
                      Session: {claim.session_id}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg font-semibold">
              Pooled Sessions ({pool.sessions.length})
            </CardTitle>
          </CardHeader>
          <CardContent>
            {pool.sessions.length === 0 ? (
              <p className="text-muted-foreground text-sm">
                No sessions reported yet. If the pool was just enabled, wait a
                moment and refresh.
              </p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>ID</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Claim</TableHead>
                    <TableHead>Queue</TableHead>
                    <TableHead>Endpoint</TableHead>
                    <TableHead>Inserted</TableHead>
                    <TableHead>Metadata</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {pool.sessions.map((session) => (
                    <TableRow key={session.id}>
                      <TableCell className="font-mono text-xs">
                        {session.id}
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant="outline"
                          className={statusBadgeClass(session.status)}
                        >
                          {session.status}
                        </Badge>
                        {session.ws_attached && (
                          <span className="text-muted-foreground ml-2 text-xs">
                            WS attached
                          </span>
                        )}
                      </TableCell>
                      <TableCell className="text-xs">
                        {session.claimed_by_label ? (
                          <div className="flex flex-col">
                            <span>Token {session.claimed_by_label}</span>
                            {session.claim_expires_at && (
                              <span className="text-muted-foreground text-[11px]">
                                Expires{' '}
                                {new Date(
                                  session.claim_expires_at,
                                ).toLocaleTimeString()}
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="text-xs">
                        {session.in_idle_queue ? (
                          <Badge
                            variant="outline"
                            className="bg-blue-50 text-blue-900 dark:bg-blue-500/20 dark:text-blue-100"
                          >
                            queued
                          </Badge>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="text-xs">
                        {session.endpoint ? (
                          <div className="flex flex-col">
                            {session.endpoint.host && (
                              <span>{session.endpoint.host}</span>
                            )}
                            {session.endpoint.port && (
                              <span className="text-muted-foreground">
                                Port {session.endpoint.port}
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="text-xs">
                        {session.inserted_at ? (
                          new Date(session.inserted_at).toLocaleTimeString()
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="text-xs">
                        {session.metadata &&
                        Object.keys(session.metadata).length > 0 ? (
                          <span className="font-mono text-[11px]">
                            {JSON.stringify(session.metadata)}
                          </span>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg font-semibold">
              Idle Queue
            </CardTitle>
          </CardHeader>
          <CardContent>
            {pool.idle_queue.length === 0 ? (
              <p className="text-muted-foreground text-sm">
                No sessions currently in the idle queue.
              </p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {pool.idle_queue.map((id) => (
                  <Badge key={id} variant="outline" className="font-mono text-xs">
                    {id}
                  </Badge>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </Layout>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div>
      <div className="text-muted-foreground text-xs uppercase tracking-wide">
        {label}
      </div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  );
}
