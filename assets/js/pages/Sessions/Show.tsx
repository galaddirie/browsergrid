import { useEffect, useState } from 'react';

import { Link } from '@inertiajs/react';
import {
  ArrowLeft,
  ExternalLink,
  RefreshCw,
  Settings,
  StopCircle,
  Wifi,
  WifiOff,
} from 'lucide-react';

import Layout from '@/components/Layout';
import { StreamViewer } from '@/components/StreamViewer';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useSessionsChannel } from '@/hooks/useSessionsChannel';
import { Session } from '@/types';

const StatusBadge = ({ status }: { status: string }) => {
  const getStatusColor = (status: string) => {
    switch (status?.toLowerCase()) {
      case 'available':
      case 'ready':
      case 'running':
      case 'active':
      case 'claimed':
        return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
      case 'pending':
      case 'starting':
        return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200';
      case 'failed':
      case 'crashed':
      case 'terminated':
        return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
      case 'idle':
      case 'completed':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
      default:
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
    }
  };

  return (
    <Badge className={`${getStatusColor(status)} border-0`}>{status}</Badge>
  );
};

export default function SessionShow({ session }: { session: Session }) {
  const [currentSession, setCurrentSession] = useState<Session>(session);
  const [isChannelConnected, setIsChannelConnected] = useState(false);
  const [cdpData, setCdpData] = useState<any>(null);
  const [cdpLoading, setCdpLoading] = useState(false);
  const [cdpError, setCdpError] = useState<string | null>(null);
  const [isStopping, setIsStopping] = useState(false);

  const isTerminalStatus = (status: string) => {
    const normalized = (status || '').toLowerCase();
    const terminal = [
      'completed',
      'failed',
      'expired',
      'crashed',
      'timed_out',
      'terminated',
      'stopped',
    ];
    return terminal.includes(normalized);
  };

  const streamUrl =
    currentSession.stream_url ||
    (currentSession.id
      ? `/sessions/${currentSession.id}/connect/stream`
      : undefined);
  const isStreamActive = !isTerminalStatus(currentSession.status ?? '');

  const fetchCdpData = async () => {
    if (!currentSession.id) return;

    setCdpLoading(true);
    setCdpError(null);

    try {
      const response = await fetch(`${currentSession.id}/connect/json`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      const data = await response.json();
      setCdpData(data);
    } catch (error) {
      setCdpError(error instanceof Error ? error.message : 'Unknown error');
      console.error('Failed to fetch CDP data:', error);
    } finally {
      setCdpLoading(false);
    }
  };

  useEffect(() => {
    setCurrentSession(session);
  }, [session]);

  const handleStopSession = async () => {
    if (!currentSession.id || isStopping) return;

    const previousStatus = currentSession.status;

    setIsStopping(true);
    setCurrentSession(prev => ({
      ...prev,
      status: 'stopping',
    }));

    try {
      const response = await fetch(`/sessions/${currentSession.id}/stop`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token':
            document
              .querySelector('meta[name="csrf-token"]')
              ?.getAttribute('content') || '',
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      });

      if (!response.ok) {
        throw new Error(
          `Failed to stop session ${currentSession.id}: ${response.status}`,
        );
      }

      let nextStatus = 'stopped';

      try {
        const payload = await response.json();
        if (payload?.data?.status) {
          nextStatus = payload.data.status;
        }
      } catch (_error) {
        // No-op: some responses may omit JSON payloads
      }

      setCurrentSession(prev => ({
        ...prev,
        status: nextStatus,
      }));
    } catch (error) {
      console.error('Failed to stop session:', error);
      setCurrentSession(prev => ({
        ...prev,
        status: previousStatus,
      }));
    } finally {
      setIsStopping(false);
    }
  };

  const { isConnected } = useSessionsChannel({
    onSessionUpdated: updatedSession => {
      if (updatedSession.id === session.id) {
        console.log('Real-time: Session updated on show page', updatedSession);
        setCurrentSession(updatedSession);
      }
    },
    onConnect: () => {
      console.log('Real-time: Connected to sessions channel (show page)');
      setIsChannelConnected(true);
    },
    onDisconnect: () => {
      console.log('Real-time: Disconnected from sessions channel (show page)');
      setIsChannelConnected(false);
    },
  });

  useEffect(() => {
    setIsChannelConnected(isConnected);
  }, [isConnected]);

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button asChild variant="ghost" size="sm" className="h-8 w-8 p-0">
              <Link href="/sessions">
                <ArrowLeft className="h-4 w-4" />
              </Link>
            </Button>
            <div>
              <h1 className="text-2xl font-semibold tracking-tight text-neutral-900">
                Session Details
              </h1>
              <p className="mt-1 text-sm text-neutral-600">
                {currentSession.id?.slice(0, 8)}... •{' '}
                {currentSession.browser_type}{' '}
                {currentSession.headless ? '(Headless)' : '(GUI)'}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-2 text-xs">
              {isChannelConnected ? (
                <Wifi className="h-4 w-4 text-green-600" />
              ) : (
                <WifiOff className="h-4 w-4 text-gray-400" />
              )}
              <span
                className={`text-xs ${isChannelConnected ? 'text-green-600' : 'text-gray-400'}`}
              >
                {isChannelConnected ? 'Live' : 'Offline'}
              </span>
            </div>
            {currentSession.live_url && (
              <Button
                size="sm"
                asChild
                className="h-8 bg-neutral-900 text-xs text-white hover:bg-neutral-800"
              >
                <a
                  href={currentSession.live_url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <ExternalLink className="mr-1.5 h-3 w-3" />
                  Open Live Session
                </a>
              </Button>
            )}
            {!isTerminalStatus(currentSession.status ?? '') && (
              <Button
                size="sm"
                variant="destructive"
                className="h-8 text-xs"
                onClick={handleStopSession}
                disabled={isStopping}
              >
                {isStopping ? (
                  <RefreshCw className="mr-1.5 h-3 w-3 animate-spin" />
                ) : (
                  <StopCircle className="mr-1.5 h-3 w-3" />
                )}
                {isStopping ? 'Stopping...' : 'Stop Session'}
              </Button>
            )}
            <Button
              size="sm"
              variant="outline"
              className="h-8 border-neutral-200 text-xs hover:bg-neutral-50"
            >
              <Settings className="mr-1.5 h-3 w-3" />
              Configure
            </Button>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <Card className="border-neutral-200">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900">
                Session Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">ID</span>
                <span className="font-mono text-xs text-neutral-900">
                  {currentSession.id}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Status</span>
                <StatusBadge status={currentSession.status ?? 'unknown'} />
              </div>
              {currentSession.session_pool && (
                <div className="flex items-center justify-between py-1">
                  <span className="text-xs text-neutral-600">Pool</span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-neutral-900">
                      {currentSession.session_pool.name}
                    </span>
                    <Badge
                      variant="outline"
                      className="border-neutral-200 text-[10px] uppercase tracking-wide text-neutral-500"
                    >
                      {currentSession.session_pool.system ? 'System' : 'Custom'}
                    </Badge>
                  </div>
                </div>
              )}
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Created</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.inserted_at
                    ? new Date(currentSession.inserted_at).toLocaleString()
                    : 'N/A'}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Claimed</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.claimed_at
                    ? new Date(currentSession.claimed_at).toLocaleString()
                    : '—'}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">
                  Attachment Deadline
                </span>
                <span className="text-xs text-neutral-900">
                  {currentSession.attachment_deadline_at
                    ? new Date(
                        currentSession.attachment_deadline_at,
                      ).toLocaleString()
                    : '—'}
                </span>
              </div>

              {currentSession.timeout && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600">Timeout</span>
                  <span className="text-xs text-neutral-900">
                    {currentSession.timeout} minutes
                  </span>
                </div>
              )}
              {currentSession.ttl_seconds && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600">TTL</span>
                  <span className="text-xs text-neutral-900">
                    {currentSession.ttl_seconds} seconds
                  </span>
                </div>
              )}
              {currentSession.cluster && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600">Cluster</span>
                  <span className="text-xs text-neutral-900">
                    {currentSession.cluster}
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          <Card className="border-neutral-200">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900">
                Browser Configuration
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Browser</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.browser_type}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Mode</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.headless ? 'Headless' : 'GUI'}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Screen</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.screen?.width ?? 1920}×
                  {currentSession.screen?.height ?? 1080}
                </span>
              </div>
              {(currentSession.limits?.cpu || currentSession.limits?.memory ||
                currentSession.limits?.timeout_minutes) && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600">Limits</span>
                  <span className="text-xs text-neutral-900">
                    CPU {currentSession.limits?.cpu ?? 'default'} • Memory{' '}
                    {currentSession.limits?.memory ?? 'default'} • Timeout{' '}
                    {currentSession.limits?.timeout_minutes ?? 'default'}m
                  </span>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        <Card className="border-neutral-200">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-neutral-900">
              Live Browser Stream
            </CardTitle>
            <p className="text-xs text-neutral-500">
              Real-time Xvfb preview for quick diagnostics.
            </p>
          </CardHeader>
          <CardContent>
            <StreamViewer
              sessionId={currentSession.id}
              streamUrl={streamUrl}
              isActive={isStreamActive}
              className="max-h-[640px]"
            />
          </CardContent>
        </Card>

        <Card className="border-neutral-200">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-neutral-900">
              Browser Debug Info
            </CardTitle>
            <p className="text-xs text-neutral-500">
              Chrome DevTools Protocol JSON data.
            </p>
          </CardHeader>
          <CardContent>
            {cdpLoading && (
              <div className="flex items-center gap-2 text-sm text-neutral-600">
                <div className="h-4 w-4 animate-spin rounded-full border-b-2 border-neutral-600"></div>
                Loading CDP data...
              </div>
            )}

            {cdpError && (
              <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-600">
                <strong>Error:</strong> {cdpError}
              </div>
            )}

            {cdpData && (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-neutral-900">
                    JSON Response
                  </span>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={fetchCdpData}
                    className="h-7 text-xs"
                  >
                    Refresh
                  </Button>
                </div>
                <pre className="text-primary-foreground max-h-96 overflow-x-auto overflow-y-auto rounded bg-neutral-900 p-3 text-xs">
                  {JSON.stringify(cdpData, null, 2)}
                </pre>
              </div>
            )}

            {!cdpLoading && !cdpError && !cdpData && (
              <Button
                size="sm"
                variant="outline"
                onClick={fetchCdpData}
                className="h-7 text-xs"
              >
                Load CDP Data
              </Button>
            )}
          </CardContent>
        </Card>
      </div>
    </Layout>
  );
}
