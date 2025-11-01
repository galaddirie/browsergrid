import { ColumnDef } from "@tanstack/react-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  CheckSquare,
  Eye,
  ExternalLink,
  Globe,
  Square,
  StopCircle,
  Trash2,
  RefreshCw,
} from "lucide-react";
import { Link } from "@inertiajs/react";
import { Session } from "@/types";

export const columns = (
  selectedSessions: Set<string>,
  handleSelectSession: (sessionId: string, checked: boolean) => void,
  handleSelectAll: (checked: boolean) => void,
  isAllSelected: boolean,
  isPartialSelected: boolean,
  handleDeleteClick: (session: Session) => void,
  handleStopSession: (session: Session) => void,
  isSessionStopping: (id?: string | null) => boolean,
  isTerminalStatus: (status: string) => boolean
): ColumnDef<Session>[] => [
  {
    id: "select",
    header: () => (
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
    ),
    cell: ({ row }) => {
      const session = row.original;
      return (
        <Button
          variant="ghost"
          size="sm"
          onClick={(e) => {
            e.stopPropagation();
            if (session.id && session.id.trim()) {
              handleSelectSession(session.id, !selectedSessions.has(session.id));
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
      );
    },
    enableSorting: false,
    enableHiding: false,
    size: 48,
  },
  {
    accessorKey: "id",
    header: "Session",
    cell: ({ row }) => {
      const session = row.original;
      return (
        <div className="space-y-0.5">
          <div className="font-mono text-xs font-medium text-neutral-900">
            {session.id?.slice(0, 8)}...
          </div>
        </div>
      );
    },
  },
  {
    accessorKey: "browser_type",
    header: "Browser",
    cell: ({ row }) => {
      const session = row.original;
      return (
        <div className="flex items-center gap-2">
          <Globe className="h-3 w-3 text-neutral-400" />
          <span className="text-xs font-medium text-neutral-900">
            {session.browser_type}
          </span>
          <Badge
            variant="outline"
            className="border-neutral-200 px-1.5 py-0 text-xs text-neutral-600"
          >
            {session.headless ? 'Headless' : 'GUI'}
          </Badge>
        </div>
      );
    },
  },
  {
    id: "pool",
    header: "Pool",
    cell: ({ row }) => {
      const session = row.original;
      return session.session_pool ? (
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
      );
    },
  },
  {
    id: "user",
    header: "User",
    cell: ({ row }) => {
      const session = row.original;
      return session.user ? (
        <div className="space-y-0.5">
          <div className="text-xs font-medium text-neutral-900">
            {session.user.email}
          </div>
          {session.user.is_admin && (
            <Badge
              variant="outline"
              className="border-neutral-200 px-1.5 py-0 text-[10px] uppercase tracking-wide text-neutral-500"
            >
              Admin
            </Badge>
          )}
        </div>
      ) : (
        <span className="text-xs text-neutral-400">—</span>
      );
    },
  },
  {
    accessorKey: "status",
    header: "Status",
    cell: ({ row }) => {
      const session = row.original;
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
        <Badge className={`${getStatusColor(session.status || 'unknown')} border-0`}>
          {session.status}
        </Badge>
      );
    },
  },
  {
    accessorKey: "inserted_at",
    header: "Created",
    cell: ({ row }) => {
      const session = row.original;
      return (
        <div className="space-y-0.5">
          <div className="text-xs text-neutral-900">
            {session.inserted_at
              ? new Date(session.inserted_at).toLocaleDateString()
              : 'N/A'}
          </div>
          <div className="text-xs text-neutral-500">
            {session.inserted_at
              ? new Date(session.inserted_at).toLocaleTimeString()
              : ''}
          </div>
        </div>
      );
    },
  },
  {
    id: "actions",
    header: "Actions",
    cell: ({ row }) => {
      const session = row.original;
      return (
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
              onClick={() => handleStopSession(session)}
              disabled={isSessionStopping(session.id)}
              className={`h-7 w-7 p-0 text-red-600 hover:bg-red-50 ${
                isSessionStopping(session.id) ? 'cursor-not-allowed opacity-60' : ''
              }`}
              title="Stop session"
            >
              {isSessionStopping(session.id) ? (
                <RefreshCw className="h-3 w-3 animate-spin" />
              ) : (
                <StopCircle className="h-3 w-3" />
              )}
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
      );
    },
    enableSorting: false,
  },
];
