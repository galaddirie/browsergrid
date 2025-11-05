import { useEffect, useMemo, useState } from 'react';

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
import {
  buildDefaultSessionForm,
  buildSessionFormData,
  fetchWithCsrf,
} from './utils';


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
  const [session, setSession] = useState<Partial<SessionFormData>>(() =>
    buildDefaultSessionForm(default_browser as Browser | undefined),
  );

  useEffect(() => {
    if (isModalOpen) {
      setSession(buildDefaultSessionForm(default_browser as Browser | undefined));
    }
  }, [isModalOpen, default_browser]);

  useEffect(() => {
    setSessionsList(sessions || []);
    setSessionsTotal(total || 0);
  }, [sessions, total]);

  const { isConnected: isChannelConnected } = useSessionsChannel({
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
    },
    onDisconnect: () => {
      console.log('Real-time: Disconnected from sessions channel');
    },
  });

  const stats = useMemo(() => {
    const list = sessionsList ?? [];
    const normalize = (status?: string) => status?.toLowerCase() ?? '';

    const matches = (session: Session, acceptable: string[]) =>
      acceptable.includes(normalize(session.status));

    return {
      total: sessionsTotal,
      running: list.filter(session => matches(session, ['running', 'claimed'])).length,
      ready: list.filter(session => matches(session, ['ready', 'available'])).length,
      failed: list.filter(session => matches(session, ['failed', 'crashed', 'error'])).length,
    };
  }, [sessionsList, sessionsTotal]);

  const isSessionStopping = (id?: string | null) =>
    Boolean(id && stoppingSessions.has(id));

  const handleCreateSession = async (sessionData: Partial<SessionFormData>) => {
    setIsLoading(true);

    const backendData = formDataToSession(sessionData);
    const payload = buildSessionFormData(backendData);

    router.post(
      '/sessions',
      payload,
      {
        onFinish: () => {
          setIsLoading(false);
          setIsModalOpen(false);
        },
        onSuccess: () => {
          setSession(buildDefaultSessionForm(default_browser as Browser | undefined));
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
    if (checked) {
      const allIds = (sessionsList ?? [])
        .map(session => session.id)
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

      const results = await Promise.all(
        validSessionIds.map(async sessionId => {
          try {
            const response = await fetchWithCsrf(`/sessions/${sessionId}`, {
              method: 'DELETE',
            });

            if (!response.ok) {
              throw new Error(
                `Failed to delete session ${sessionId}: ${response.status}`,
              );
            }

            return { sessionId, ok: true as const };
          } catch (error) {
            console.error(`Failed to delete session ${sessionId}`, error);
            return { sessionId, ok: false as const, error };
          }
        }),
      );

      const successfulDeletes = results.filter(result => result.ok).length;
      const failedDeletes = results.filter(result => !result.ok);

      if (failedDeletes.length > 0) {
        console.error(
          'Failed delete requests:',
          failedDeletes.map(result => ({
            sessionId: result.sessionId,
            error: result.error instanceof Error ? result.error.message : result.error,
          })),
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
      const response = await fetchWithCsrf(`/sessions/${sessionId}/stop`, {
        method: 'POST',
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
              onClick={() => router.reload({ only: ['sessions', 'total'] })}
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
              isSessionStopping
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
