import { useEffect, useState } from 'react';

import { router } from '@inertiajs/react';
import {
  Globe,
  Plus,
  RefreshCw,
  Trash2,
  Wifi,
  WifiOff,
} from 'lucide-react';

import { Header } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
import { Button } from '@/components/ui/button';
import { DataTable } from '@/components/data-table';
import { useSessionsChannel } from '@/hooks/useSessionsChannel';
import { Browser, formDataToSession, Session, SessionFormData } from '@/types';
import { columns } from './columns';
import {
  CreateSessionDialog,
  DeleteConfirmationDialog,
  BulkDeleteConfirmationDialog,
} from './dialogs';


export default function SessionsIndex({
  sessions,
  total,
  profiles,
  default_browser,
}: {
  sessions: Session[];
  total: number;
  profiles?: any[];
  default_browser?: string;
}) {
  const [sessionsList, setSessionsList] = useState<Session[]>(sessions || []);
  const [sessionsTotal, setSessionsTotal] = useState<number>(total || 0);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [sessionToDelete, setSessionToDelete] = useState<Session | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);
  const [stoppingSessions, setStoppingSessions] = useState<Set<string>>(
    () => new Set(),
  );
  const [selectedSessions, setSelectedSessions] = useState<Set<string>>(
    new Set(),
  );
  const [bulkDeleteDialogOpen, setBulkDeleteDialogOpen] = useState(false);
  const [isBulkDeleting, setIsBulkDeleting] = useState(false);
  const [isChannelConnected, setIsChannelConnected] = useState(false);
  const [session, setSession] = useState<Partial<SessionFormData>>({
    browser_type: (default_browser as Browser) || 'chrome',
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
  });

  useEffect(() => {
    if (isModalOpen) {
      setSession({
        browser_type: (default_browser as Browser) || 'chrome',
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
      });
    }
  }, [isModalOpen, default_browser]);

  useEffect(() => {
    setSessionsList(sessions || []);
    setSessionsTotal(total || 0);
  }, [sessions, total]);

  const { isConnected } = useSessionsChannel({
    onSessionCreated: newSession => {
      console.log('Real-time: Session created', newSession);
      setSessionsList(previous => [newSession, ...previous]);
      setSessionsTotal(previous => previous + 1);
    },
    onSessionUpdated: updatedSession => {
      console.log('Real-time: Session updated', updatedSession);
      setSessionsList(previous =>
        previous.map(session =>
          session.id === updatedSession.id ? updatedSession : session,
        ),
      );
    },
    onSessionDeleted: sessionId => {
      console.log('Real-time: Session deleted', sessionId);
      setSessionsList(previous =>
        previous.filter(session => session.id !== sessionId),
      );
      setSessionsTotal(previous => previous - 1);
      setSelectedSessions(previous => {
        const newSet = new Set(previous);
        newSet.delete(sessionId);
        return newSet;
      });
    },
    onConnect: () => {
      console.log('Real-time: Connected to sessions channel');
      setIsChannelConnected(true);
    },
    onDisconnect: () => {
      console.log('Real-time: Disconnected from sessions channel');
      setIsChannelConnected(false);
    },
  });

  useEffect(() => {
    setIsChannelConnected(isConnected);
  }, [isConnected]);

  const stats = {
    total: sessionsTotal,
    running:
      sessionsList?.filter((s: Session) =>
        ['running', 'claimed'].includes((s.status || '').toLowerCase()),
      ).length || 0,
    ready:
      sessionsList?.filter((s: Session) =>
        ['ready', 'available'].includes((s.status || '').toLowerCase()),
      ).length || 0,
    failed:
      sessionsList?.filter((s: Session) =>
        ['failed', 'crashed', 'error'].includes(
          (s.status || '').toLowerCase(),
        ),
      ).length || 0,
  };

  const isSessionStopping = (id?: string | null) =>
    Boolean(id && stoppingSessions.has(id));

  const handleCreateSession = async (sessionData: Partial<SessionFormData>) => {
    setIsLoading(true);

    const backendData = formDataToSession(sessionData);

    const payload = new FormData();

    if (backendData.name !== undefined) payload.append('session[name]', backendData.name);
    payload.append('session[browser_type]', backendData.browser_type || 'chrome');
    if (backendData.profile_id !== undefined) payload.append('session[profile_id]', backendData.profile_id);
    payload.append('session[headless]', backendData.headless ? 'true' : 'false');
    if (backendData.timeout !== undefined) payload.append('session[timeout]', backendData.timeout.toString());
    if (backendData.ttl_seconds !== undefined && backendData.ttl_seconds !== null) payload.append('session[ttl_seconds]', backendData.ttl_seconds.toString());
    if (backendData.cluster !== undefined) payload.append('session[cluster]', backendData.cluster);
    if (backendData.session_pool_id !== undefined) payload.append('session[session_pool_id]', backendData.session_pool_id);

    if (backendData.screen) {
      payload.append('session[screen][width]', backendData.screen.width.toString());
      payload.append('session[screen][height]', backendData.screen.height.toString());
      payload.append('session[screen][dpi]', backendData.screen.dpi.toString());
      payload.append('session[screen][scale]', backendData.screen.scale.toString());
    }

    if (backendData.limits) {
      if (backendData.limits.cpu !== undefined) payload.append('session[limits][cpu]', backendData.limits.cpu.toString());
      if (backendData.limits.memory !== undefined) payload.append('session[limits][memory]', backendData.limits.memory);
      if (backendData.limits.timeout_minutes !== undefined) payload.append('session[limits][timeout_minutes]', backendData.limits.timeout_minutes.toString());
    }

    router.post(
      '/sessions',
      payload,
      {
        onFinish: () => {
          setIsLoading(false);
          setIsModalOpen(false);
        },
        onError: errors => {
          console.error('Failed to create session:', errors);
        },
      },
    );
  };

  const handleSubmit = () => {
    handleCreateSession(session);
  };

  const handleCancel = () => {
    setIsModalOpen(false);
  };

  const handleDeleteClick = (session: Session) => {
    setSessionToDelete(session);
    setDeleteDialogOpen(true);
  };

  const handleDeleteConfirm = async () => {
    if (!sessionToDelete || !sessionToDelete.id) return;

    setIsDeleting(true);

    router.delete(`/sessions/${sessionToDelete.id}`, {
      onFinish: () => {
        setIsDeleting(false);
        setDeleteDialogOpen(false);
        setSessionToDelete(null);
      },
      onError: errors => {
        console.error('Failed to delete session:', errors);
      },
    });
  };

  const handleDeleteCancel = () => {
    setDeleteDialogOpen(false);
    setSessionToDelete(null);
  };

  const handleSelectSession = (sessionId: string, checked: boolean) => {
    if (!sessionId || !sessionId.trim()) return;

    const newSelected = new Set(selectedSessions);
    if (checked) {
      newSelected.add(sessionId);
    } else {
      newSelected.delete(sessionId);
    }
    setSelectedSessions(newSelected);
  };

  const handleSelectAll = (checked: boolean) => {
    if (checked && sessions) {
      const allIds = sessions
        .map(s => s.id)
        .filter(id => id && id.trim()) as string[];
      setSelectedSessions(new Set(allIds));
    } else {
      setSelectedSessions(new Set());
    }
  };

  const isAllSelected =
    sessionsList &&
    sessionsList.length > 0 &&
    selectedSessions.size === sessionsList.length;
  const isPartialSelected = selectedSessions.size > 0 && !isAllSelected;

  const handleBulkDeleteClick = () => {
    setBulkDeleteDialogOpen(true);
  };

  const handleBulkDeleteConfirm = async () => {
    if (selectedSessions.size === 0) return;

    setIsBulkDeleting(true);
    try {
      const validSessionIds = [...selectedSessions].filter(
        id => id && id.trim(),
      );

      if (validSessionIds.length === 0) {
        console.error('No valid session IDs to delete');
        setIsBulkDeleting(false);
        setBulkDeleteDialogOpen(false);
        return;
      }

      const deletePromises = validSessionIds.map(sessionId =>
        fetch(`/sessions/${sessionId}`, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token':
              document
                .querySelector('meta[name="csrf-token"]')
                ?.getAttribute('content') || '',
          },
        }),
      );

      const results = await Promise.allSettled(deletePromises);
      const successfulDeletes = results.filter(
        result => result.status === 'fulfilled',
      ).length;
      const failedDeletes = results.filter(
        result => result.status === 'rejected',
      ).length;

      console.log(
        `Bulk delete results: ${successfulDeletes} successful, ${failedDeletes} failed`,
      );

      if (failedDeletes > 0) {
        const failedResults = results.filter(
          result => result.status === 'rejected',
        ) as PromiseRejectedResult[];
        console.error(
          'Failed delete requests:',
          failedResults.map(r => r.reason),
        );
      }

      if (successfulDeletes > 0) {
        router.reload({ only: ['sessions', 'total'] });
        setSelectedSessions(new Set());
      } else {
        console.error('Failed to delete any sessions');
      }
    } catch (error) {
      console.error('Error during bulk delete:', error);
    } finally {
      setIsBulkDeleting(false);
      setBulkDeleteDialogOpen(false);
    }
  };

  const handleBulkDeleteCancel = () => {
    setBulkDeleteDialogOpen(false);
  };

  const handleStopSession = async (sessionDetails: Session) => {
    const sessionId = sessionDetails.id;
    if (!sessionId || stoppingSessions.has(sessionId)) return;

    const currentStatus = sessionDetails.status;

    setStoppingSessions(previous => {
      const next = new Set(previous);
      next.add(sessionId);
      return next;
    });

    setSessionsList(previous =>
      previous.map(session =>
        session.id === sessionId ? { ...session, status: 'stopping' } : session,
      ),
    );

    try {
      const response = await fetch(`/sessions/${sessionId}/stop`, {
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
          `Failed to stop session ${sessionId}: ${response.status}`,
        );
      }

      let nextStatus = 'stopped';

      try {
        const payload = await response.json();
        if (payload?.data?.status) {
          nextStatus = payload.data.status;
        }
      } catch (_error) {
        // Swallow JSON parsing errors - payload optional
      }

      setSessionsList(previous =>
        previous.map(session =>
          session.id === sessionId ? { ...session, status: nextStatus } : session,
        ),
      );
    } catch (error) {
      console.error('Failed to stop session:', error);
      setSessionsList(previous =>
        previous.map(session =>
          session.id === sessionId ? { ...session, status: currentStatus } : session,
        ),
      );
    } finally {
      setStoppingSessions(previous => {
        const next = new Set(previous);
        next.delete(sessionId);
        return next;
      });
    }
  };

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

  return (
    <Layout>
      <Header>
        <div>
          <h1 className="mb-2 text-4xl font-bold">Browser Sessions</h1>
          <p className="text-primary/70 mb-6 text-sm">
            Manage and monitor your browser automation sessions
          </p>
          <div className="flex items-center gap-6 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Total:</span>
              <span className="font-semibold text-neutral-900">
                {stats.total}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Running:</span>
              <span className="font-semibold text-neutral-900">
                {stats.running}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Ready:</span>
              <span className="font-semibold text-neutral-900">
                {stats.ready}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Failed:</span>
              <span className="font-semibold text-neutral-900">
                {stats.failed}
              </span>
            </div>
            <div className="ml-auto flex items-center gap-2">
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
          </div>
          <div className="mb-6 flex space-x-2">
            <Button
              onClick={() => window.location.reload()}
              variant="outline"
              size="sm"
              className="h-8 text-xs"
            >
              <RefreshCw className="mr-1.5 h-3 w-3" />
              Refresh
            </Button>
            <Button
              size="sm"
              className="h-8 bg-neutral-900 text-xs text-white hover:bg-neutral-800"
              onClick={() => setIsModalOpen(true)}
            >
              <Plus className="mr-1.5 h-3 w-3" />
              New Session
            </Button>
            {selectedSessions.size > 0 && (
              <Button
                size="sm"
                variant="destructive"
                className="h-8 text-xs"
                onClick={handleBulkDeleteClick}
              >
                <Trash2 className="mr-1.5 h-3 w-3" />
                Delete Selected ({selectedSessions.size})
              </Button>
            )}
          </div>
        </div>
      </Header>
      <div className="space-y-6">




        {!sessionsList || sessionsList.length === 0 ? (
          <div className="py-12 text-center">
            <Globe className="mx-auto mb-3 h-8 w-8 text-neutral-400" />
            <h3 className="mb-1 text-sm font-semibold text-neutral-900">
              No sessions yet
            </h3>
            <p className="mb-4 text-xs text-neutral-600">
              Get started by creating your first browser session.
            </p>
            <Button
              size="sm"
              className="h-8 bg-neutral-900 text-xs text-white hover:bg-neutral-800"
              onClick={() => setIsModalOpen(true)}
            >
              <Plus className="mr-1.5 h-3 w-3" />
              Create New Session
            </Button>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <DataTable
              columns={columns(
                selectedSessions,
                handleSelectSession,
                handleSelectAll,
                isAllSelected,
                isPartialSelected,
                handleDeleteClick,
                handleStopSession,
                isSessionStopping,
                isTerminalStatus
              )}
              data={sessionsList}
              searchKey="id"
              searchPlaceholder="Search sessions..."
              showPagination={true}
              pageSize={10}
            />
          </div>
        )}

      </div>

      <CreateSessionDialog
        isModalOpen={isModalOpen}
        setIsModalOpen={setIsModalOpen}
        session={session}
        setSession={setSession}
        profiles={profiles}
        defaultBrowser={default_browser as Browser}
        handleSubmit={handleSubmit}
        handleCancel={handleCancel}
        isLoading={isLoading}
      />

      <DeleteConfirmationDialog
        deleteDialogOpen={deleteDialogOpen}
        setDeleteDialogOpen={setDeleteDialogOpen}
        sessionToDelete={sessionToDelete}
        handleDeleteConfirm={handleDeleteConfirm}
        handleDeleteCancel={handleDeleteCancel}
        isDeleting={isDeleting}
      />

      <BulkDeleteConfirmationDialog
        bulkDeleteDialogOpen={bulkDeleteDialogOpen}
        setBulkDeleteDialogOpen={setBulkDeleteDialogOpen}
        selectedSessions={selectedSessions}
        handleBulkDeleteConfirm={handleBulkDeleteConfirm}
        handleBulkDeleteCancel={handleBulkDeleteCancel}
        isBulkDeleting={isBulkDeleting}
      />
    </Layout>
  );
}
