import { RefreshCw } from 'lucide-react';

import { SessionForm } from '@/pages/Sessions/form';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Browser, Session, SessionFormData } from '@/types';

interface CreateSessionDialogProps {
  isModalOpen: boolean;
  setIsModalOpen: (open: boolean) => void;
  session: Partial<SessionFormData>;
  setSession: (session: Partial<SessionFormData>) => void;
  profiles?: any[];
  defaultBrowser?: Browser;
  handleSubmit: () => void;
  handleCancel: () => void;
  isLoading: boolean;
}

export function CreateSessionDialog({
  isModalOpen,
  setIsModalOpen,
  session,
  setSession,
  profiles,
  defaultBrowser,
  handleSubmit,
  handleCancel,
  isLoading,
}: CreateSessionDialogProps) {
  return (
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
              defaultBrowser={defaultBrowser}
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
  );
}

interface DeleteConfirmationDialogProps {
  deleteDialogOpen: boolean;
  setDeleteDialogOpen: (open: boolean) => void;
  sessionToDelete: Session | null;
  handleDeleteConfirm: () => void;
  handleDeleteCancel: () => void;
  isDeleting: boolean;
}

export function DeleteConfirmationDialog({
  deleteDialogOpen,
  setDeleteDialogOpen,
  sessionToDelete,
  handleDeleteConfirm,
  handleDeleteCancel,
  isDeleting,
}: DeleteConfirmationDialogProps) {
  return (
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
  );
}

interface BulkDeleteConfirmationDialogProps {
  bulkDeleteDialogOpen: boolean;
  setBulkDeleteDialogOpen: (open: boolean) => void;
  selectedSessions: Set<string>;
  handleBulkDeleteConfirm: () => void;
  handleBulkDeleteCancel: () => void;
  isBulkDeleting: boolean;
}

export function BulkDeleteConfirmationDialog({
  bulkDeleteDialogOpen,
  setBulkDeleteDialogOpen,
  selectedSessions,
  handleBulkDeleteConfirm,
  handleBulkDeleteCancel,
  isBulkDeleting,
}: BulkDeleteConfirmationDialogProps) {
  return (
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
  );
}
