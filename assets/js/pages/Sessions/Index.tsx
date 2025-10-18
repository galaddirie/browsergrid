import { useEffect, useState } from 'react';

import { Link, router } from '@inertiajs/react';
import {
  CheckSquare,
  ExternalLink,
  Eye,
  Globe,
  Plus,
  RefreshCw,
  Square,
  StopCircle,
  Trash2,
  Wifi,
  WifiOff,
} from 'lucide-react';

import { Header } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
import { SessionForm } from '@/components/SessionForm';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { useSessionsChannel } from '@/hooks/useSessionsChannel';
import { formDataToSession, Session, SessionFormData } from '@/types';

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

export default function SessionsIndex({
  sessions,
  total,
  profiles,
}: {
  sessions: Session[];
  total: number;
  profiles?: any[];
}) {
  const [sessionsList, setSessionsList] = useState<Session[]>(sessions || []);
  const [sessionsTotal, setSessionsTotal] = useState<number>(total || 0);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [sessionToDelete, setSessionToDelete] = useState<Session | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);
  const [selectedSessions, setSelectedSessions] = useState<Set<string>>(
    new Set(),
  );
  const [bulkDeleteDialogOpen, setBulkDeleteDialogOpen] = useState(false);
  const [isBulkDeleting, setIsBulkDeleting] = useState(false);
  const [isChannelConnected, setIsChannelConnected] = useState(false);
  const [session, setSession] = useState<Partial<SessionFormData>>({
    browser_type: 'chrome',
    version: 'latest',
    headless: false,
    screen: {
      width: 1920,
      height: 1080,
      dpi: 96,
      scale: 1.0,
    },
    resource_limits: {
      cpu: 2.0,
      memory: '4GB',
      timeout_minutes: 30,
    },
  });

  useEffect(() => {
    if (isModalOpen) {
      setSession({
        browser_type: 'chrome',
        version: 'latest',
        headless: false,

        screen: {
          width: 1920,
          height: 1080,
          dpi: 96,
          scale: 1.0,
        },
        resource_limits: {
          cpu: 2.0,
          memory: '4GB',
          timeout_minutes: 30,
        },
      });
    }
  }, [isModalOpen]);

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

  const handleCreateSession = async (sessionData: Partial<SessionFormData>) => {
    setIsLoading(true);

    const backendData = formDataToSession(sessionData);
    // Convert to a simple payload format
    const payload = {
      name: backendData.name,
      browser_type: backendData.browser_type,
      profile_id: backendData.profile_id,
      options: backendData.options,
    };

    router.post(
      '/sessions',
      { session: payload },
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

  const isTerminalStatus = (status: string) => {
    const terminal = [
      'completed',
      'failed',
      'expired',
      'crashed',
      'timed_out',
      'terminated',
    ];
    return terminal.includes(status);
  };

  return (
    <Layout>
      <Header>
        <div>
          <h1 className="mb-2 text-4xl font-bold">Browser Sessions</h1>
          <p className="text-primary/70 mb-6 text-sm">
            Manage and monitor your browser automation sessions
          </p>
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

        <Card className="border-neutral-200/60">
          <CardHeader className="border-b border-neutral-100 bg-neutral-50/30 py-3">
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <h2 className="font-medium text-neutral-900">Sessions</h2>
            </div>
          </CardHeader>
          <CardContent className="p-0">
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
              <Table>
                <TableHeader>
                  <TableRow className="border-neutral-100">
                    <TableHead className="h-10 w-12 text-xs font-medium text-neutral-700">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleSelectAll(!isAllSelected)}
                        className="h-6 w-6 p-0 hover:bg-neutral-100"
                      >
                        {isAllSelected ? (
                          <CheckSquare className="h-4 w-4 text-blue-600" />
                        ) : isPartialSelected ? (
                          <div className="h-4 w-4 rounded-sm border-2 border-blue-600 bg-blue-50" />
                        ) : (
                          <Square className="h-4 w-4 text-neutral-400" />
                        )}
                      </Button>
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700">
                      Session
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700">
                      Browser
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700">
                      Pool
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700">
                      Status
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700">
                      Created
                    </TableHead>
                    <TableHead className="h-10 text-right text-xs font-medium text-neutral-700">
                      Actions
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {sessionsList.map((session: Session) => (
                    <TableRow
                      key={session.id}
                      className="border-neutral-100 transition-colors duration-150 hover:bg-neutral-50/50"
                    >
                      <TableCell className="w-12 py-3">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={e => {
                            e.stopPropagation();
                            if (session.id && session.id.trim()) {
                              handleSelectSession(
                                session.id,
                                !selectedSessions.has(session.id),
                              );
                            }
                          }}
                          className="h-6 w-6 p-0 hover:bg-neutral-100"
                        >
                          {session.id && selectedSessions.has(session.id) ? (
                            <CheckSquare className="h-4 w-4 text-blue-600" />
                          ) : (
                            <Square className="h-4 w-4 text-neutral-400" />
                          )}
                        </Button>
                      </TableCell>
                      <TableCell className="py-3">
                        <div className="space-y-0.5">
                          <div className="font-mono text-xs font-medium text-neutral-900">
                            {session.id?.slice(0, 8)}...
                          </div>
                        </div>
                      </TableCell>
                      <TableCell className="py-3">
                        <div className="flex items-center gap-2">
                          <Globe className="h-3 w-3 text-neutral-400" />
                          <span className="text-xs font-medium text-neutral-900">
                            {session.browser_type}
                          </span>
                          <Badge
                            variant="outline"
                            className="border-neutral-200 px-1.5 py-0 text-xs text-neutral-600"
                          >
                            {session.options?.version || 'latest'}
                          </Badge>
                        </div>
                      </TableCell>
                      <TableCell className="py-3">
                        {session.session_pool ? (
                          <div className="space-y-0.5">
                            <div className="text-xs font-medium text-neutral-900">
                              {session.session_pool.name}
                            </div>
                            <Badge
                              variant="outline"
                              className="border-neutral-200 px-1.5 py-0 text-[10px] uppercase tracking-wide text-neutral-500"
                            >
                              {session.session_pool.system ? 'System' : 'Custom'}
                            </Badge>
                          </div>
                        ) : (
                          <span className="text-xs text-neutral-400">—</span>
                        )}
                      </TableCell>
                      <TableCell className="py-3">
                        <StatusBadge status={session.status || 'unknown'} />
                      </TableCell>
                      <TableCell className="py-3">
                        <div className="space-y-0.5">
                          <div className="text-xs text-neutral-900">
                            {session.inserted_at
                              ? new Date(
                                  session.inserted_at,
                                ).toLocaleDateString()
                              : 'N/A'}
                          </div>
                          <div className="text-xs text-neutral-500">
                            {session.inserted_at
                              ? new Date(
                                  session.inserted_at,
                                ).toLocaleTimeString()
                              : ''}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell className="py-3 text-right">
                        <div className="flex items-center justify-end gap-1">
                          <Button
                            size="sm"
                            variant="ghost"
                            asChild
                            className="h-7 w-7 p-0 hover:bg-neutral-100"
                          >
                            <Link href={`/sessions/${session.id}`}>
                              <Eye className="h-3 w-3" />
                            </Link>
                          </Button>
                          {session.live_url && (
                            <Button
                              size="sm"
                              variant="ghost"
                              asChild
                              className="h-7 w-7 p-0 hover:bg-neutral-100"
                            >
                              <a
                                href={session.live_url}
                                target="_blank"
                                rel="noopener noreferrer"
                              >
                                <ExternalLink className="h-3 w-3" />
                              </a>
                            </Button>
                          )}
                          {!isTerminalStatus(session.status ?? '') && (
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-7 w-7 p-0 text-red-600 hover:bg-red-50"
                              title="Stop session"
                            >
                              <StopCircle className="h-3 w-3" />
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => handleDeleteClick(session)}
                            className="h-7 w-7 p-0 text-red-600 hover:bg-red-50"
                            title="Delete session"
                          >
                            <Trash2 className="h-3 w-3" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>

      <Dialog
        open={isModalOpen}
        onOpenChange={(open: boolean) => !open && setIsModalOpen(false)}
      >
        <DialogContent className="flex max-h-[90vh] max-w-4xl flex-col p-0">
          <DialogHeader className="flex-shrink-0 border-b px-6 py-4">
            <DialogTitle className="text-xl font-semibold">
              Create New Session
            </DialogTitle>
          </DialogHeader>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto">
            <div className="px-6">
              <SessionForm
                session={session}
                onSessionChange={setSession}
                profiles={profiles}
              />
            </div>
          </div>

          {/* Action Buttons - Sticky Footer */}
          <div className="flex flex-shrink-0 justify-end gap-2 border-t bg-white px-6 py-4">
            <Button
              variant="outline"
              onClick={handleCancel}
              disabled={isLoading}
              type="button"
            >
              Cancel
            </Button>
            <Button onClick={handleSubmit} disabled={isLoading} type="button">
              {isLoading && <RefreshCw className="mr-2 h-4 w-4 animate-spin" />}
              Create Session
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={deleteDialogOpen}
        onOpenChange={(open: boolean) => !open && setDeleteDialogOpen(false)}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-lg font-semibold">
              Delete Session
            </DialogTitle>
          </DialogHeader>

          <div className="py-4">
            <p className="text-sm text-neutral-600">
              Are you sure you want to delete the session{' '}
              <span className="font-mono font-medium text-neutral-900">
                {sessionToDelete?.id?.slice(0, 8)}...
              </span>
              ?
            </p>
            <p className="mt-2 text-xs text-neutral-500">
              This action cannot be undone. The session and all associated data
              will be permanently removed.
            </p>
          </div>

          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={handleDeleteCancel}
              disabled={isDeleting}
              size="sm"
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteConfirm}
              disabled={isDeleting}
              size="sm"
            >
              {isDeleting && (
                <RefreshCw className="mr-2 h-3 w-3 animate-spin" />
              )}
              Delete
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Bulk Delete Confirmation Dialog */}
      <Dialog
        open={bulkDeleteDialogOpen}
        onOpenChange={(open: boolean) =>
          !open && setBulkDeleteDialogOpen(false)
        }
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-lg font-semibold">
              Delete Selected Sessions
            </DialogTitle>
          </DialogHeader>

          <div className="py-4">
            <p className="text-sm text-neutral-600">
              Are you sure you want to delete{' '}
              <span className="font-semibold text-neutral-900">
                {selectedSessions.size} session
                {selectedSessions.size !== 1 ? 's' : ''}
              </span>
              ?
            </p>
            <p className="mt-2 text-xs text-neutral-500">
              This action cannot be undone. All selected sessions and their
              associated data will be permanently removed.
            </p>
          </div>

          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={handleBulkDeleteCancel}
              disabled={isBulkDeleting}
              size="sm"
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleBulkDeleteConfirm}
              disabled={isBulkDeleting}
              size="sm"
            >
              {isBulkDeleting && (
                <RefreshCw className="mr-2 h-3 w-3 animate-spin" />
              )}
              Delete {selectedSessions.size} Session
              {selectedSessions.size !== 1 ? 's' : ''}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </Layout>
  );
}
