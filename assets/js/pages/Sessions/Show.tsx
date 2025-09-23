import { useState, useEffect } from 'react';
import { Link } from '@inertiajs/react';
import { ArrowLeft, ExternalLink, Settings, StopCircle, Wifi, WifiOff } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import Layout from '@/components/Layout';
import { Session } from '@/types';
import { useSessionsChannel } from '@/hooks/useSessionsChannel';

const StatusBadge = ({ status }: { status: string }) => {
  const getStatusColor = (status: string) => {
    switch (status?.toLowerCase()) {
      case 'available':
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
    <Badge className={`${getStatusColor(status)} border-0`}>
      {status}
    </Badge>
  );
};

export default function SessionShow({ session }: { session: Session }) {
  const [currentSession, setCurrentSession] = useState<Session>(session);
  const [isChannelConnected, setIsChannelConnected] = useState(false);

  const isTerminalStatus = (status: string) => {
    const terminal = ['completed', 'failed', 'expired', 'crashed', 'timed_out', 'terminated'];
    return terminal.includes(status);
  };

  useEffect(() => {
    setCurrentSession(session);
  }, [session]);

  const { isConnected } = useSessionsChannel({
    onSessionUpdated: (updatedSession) => {
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
    }
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
              <h1 className="text-2xl font-semibold text-neutral-900 tracking-tight">
                Session Details
              </h1>
              <p className="text-sm text-neutral-600 mt-1">
                {currentSession.id?.substring(0, 8)}... • {currentSession.browser} {currentSession.version}
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
              <span className={`text-xs ${isChannelConnected ? 'text-green-600' : 'text-gray-400'}`}>
                {isChannelConnected ? 'Live' : 'Offline'}
              </span>
            </div>
            {currentSession.live_url && (
              <Button size="sm" asChild className="bg-neutral-900 hover:bg-neutral-800 text-white text-xs h-8">
                <a href={currentSession.live_url} target="_blank" rel="noopener noreferrer">
                  <ExternalLink className="h-3 w-3 mr-1.5" />
                  Open Live Session
                </a>
              </Button>
            )}
            {!isTerminalStatus(currentSession.status ?? '') && (
              <Button size="sm" variant="destructive" className="text-xs h-8">
                <StopCircle className="h-3 w-3 mr-1.5" />
                Stop Session
              </Button>
            )}
            <Button size="sm" variant="outline" className="border-neutral-200 hover:bg-neutral-50 text-xs h-8">
              <Settings className="h-3 w-3 mr-1.5" />
              Configure
            </Button>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <Card className="border-neutral-200">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900">Session Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">ID</span>
                <span className="font-mono text-xs text-neutral-900">{currentSession.id}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Status</span>
                <StatusBadge status={currentSession.status ?? 'unknown'} />
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Created</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.created_at ? new Date(currentSession.created_at).toLocaleString() : 'N/A'}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Provider</span>
                <span className="text-xs text-neutral-900">{currentSession.provider}</span>
              </div>
              {currentSession.expires_at && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600">Expires</span>
                  <span className="text-xs text-neutral-900">
                    {new Date(currentSession.expires_at).toLocaleString()}
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          <Card className="border-neutral-200">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900">Browser Configuration</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Browser</span>
                <span className="text-xs text-neutral-900">{currentSession.browser} {currentSession.version}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">OS</span>
                <span className="text-xs text-neutral-900">{currentSession.operating_system}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Mode</span>
                <span className="text-xs text-neutral-900">{currentSession.headless ? 'Headless' : 'GUI'}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600">Screen</span>
                <span className="text-xs text-neutral-900">
                  {currentSession.screen?.width}×{currentSession.screen?.height}
                </span>
              </div>
            </CardContent>
          </Card>
        </div>

        {currentSession.live_url && (
          <Card className="border-neutral-200">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900">Live Browser View</CardTitle>
              <p className="text-xs text-neutral-600">
                Real-time view of the browser session. Click and interact directly with the browser.
              </p>
            </CardHeader>
            <CardContent className="p-0">
              <div className="relative bg-black rounded-lg overflow-hidden h-[600px]">
                <iframe
                  src={currentSession.live_url}
                  className="w-full h-full border-0"
                  allow="fullscreen"
                  title={`Live browser session ${currentSession.id}`}
                />
                <div className="absolute top-2 left-2 bg-black/70 text-white text-xs px-2 py-1 rounded">
                  Session: {currentSession.id?.substring(0, 8)}...
                </div>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </Layout>
  );
}