import { Link } from '@inertiajs/react';
import { Eye, Package, Play, Plus, Trash2 } from 'lucide-react';

import { useSetHeader } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
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

const StatusBadge = ({ status }: { status: string }) => {
  const getStatusColor = (status: string) => {
    switch (status?.toLowerCase()) {
      case 'running':
      case 'deploying':
        return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
      case 'pending':
        return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200';
      case 'failed':
      case 'error':
        return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
      case 'stopped':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
      default:
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
    }
  };

  return (
    <Badge className={`${getStatusColor(status)} border-0`}>{status}</Badge>
  );
};

interface Deployment {
  id: string;
  name: string;
  description?: string;
  status: string;
  last_deployed_at?: string;
  inserted_at: string;
}

export default function DeploymentsIndex({
  deployments,
  total,
}: {
  deployments: Deployment[];
  total: number;
}) {
  useSetHeader({
    title: 'Deployments',
    description: 'Manage and deploy your browser automation projects',
    actions: (
      <Button
        size="sm"
        className="h-8 bg-neutral-900 text-xs text-white hover:bg-neutral-800"
        asChild
      >
        <Link href="/deployments/new">
          <Plus className="mr-1.5 h-3 w-3" />
          New Deployment
        </Link>
      </Button>
    ),
  });

  const stats = {
    total: total || 0,
    running:
      deployments?.filter((d: Deployment) =>
        ['running', 'deploying'].includes(d.status),
      ).length || 0,
    pending:
      deployments?.filter((d: Deployment) => d.status === 'pending').length ||
      0,
    failed:
      deployments?.filter((d: Deployment) =>
        ['failed', 'error'].includes(d.status),
      ).length || 0,
  };

  return (
    <Layout>
      <div className="space-y-6">
        {/* Stats */}
        {deployments && deployments.length > 0 && (
          <div className="flex items-center gap-6 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">
                Total:
              </span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">
                {stats.total}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">
                Running:
              </span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">
                {stats.running}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">
                Pending:
              </span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">
                {stats.pending}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">
                Failed:
              </span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">
                {stats.failed}
              </span>
            </div>
          </div>
        )}

        {/* Deployments Table */}
        <Card className="border-neutral-200/60 p-0 dark:border-neutral-800">
          <CardHeader className="flex flex-row items-center justify-between border-b border-neutral-100 bg-neutral-50/30 py-3 dark:border-neutral-800 dark:bg-neutral-900/30">
            <CardTitle className="text-base">Deployments</CardTitle>
          </CardHeader>
          <CardContent className="p-0 pt-0">
            {!deployments || deployments.length === 0 ? (
              <div className="py-12 text-center">
                <Package className="mx-auto mb-3 h-8 w-8 text-neutral-400" />
                <h3 className="mb-1 text-sm font-semibold text-neutral-900 dark:text-neutral-100">
                  No deployments yet
                </h3>
                <p className="mb-4 text-xs text-neutral-600 dark:text-neutral-400">
                  Get started by creating your first deployment.
                </p>
                <Button
                  size="sm"
                  className="h-8 bg-neutral-900 text-xs text-white hover:bg-neutral-800"
                  asChild
                >
                  <Link href="/deployments/new">
                    <Plus className="mr-1.5 h-3 w-3" />
                    Create Deployment
                  </Link>
                </Button>
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow className="border-neutral-100 dark:border-neutral-800">
                    <TableHead className="h-10 text-xs font-medium text-neutral-700 dark:text-neutral-300">
                      Name
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700 dark:text-neutral-300">
                      Status
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700 dark:text-neutral-300">
                      Last Deployed
                    </TableHead>
                    <TableHead className="h-10 text-xs font-medium text-neutral-700 dark:text-neutral-300">
                      Created
                    </TableHead>
                    <TableHead className="h-10 text-right text-xs font-medium text-neutral-700 dark:text-neutral-300">
                      Actions
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {deployments.map((deployment: Deployment) => (
                    <TableRow
                      key={deployment.id}
                      className="border-neutral-100 transition-colors duration-150 hover:bg-neutral-50/50 dark:border-neutral-800 dark:hover:bg-neutral-900/50"
                    >
                      <TableCell className="py-3">
                        <div className="space-y-0.5">
                          <div className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                            {deployment.name}
                          </div>
                          {deployment.description && (
                            <div className="max-w-[200px] truncate text-xs text-neutral-500 dark:text-neutral-400">
                              {deployment.description}
                            </div>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="py-3">
                        <StatusBadge status={deployment.status} />
                      </TableCell>
                      <TableCell className="py-3">
                        <div className="text-xs text-neutral-900 dark:text-neutral-100">
                          {deployment.last_deployed_at
                            ? new Date(
                                deployment.last_deployed_at,
                              ).toLocaleDateString()
                            : 'Never'}
                        </div>
                      </TableCell>
                      <TableCell className="py-3">
                        <div className="space-y-0.5">
                          <div className="text-xs text-neutral-900 dark:text-neutral-100">
                            {new Date(
                              deployment.inserted_at,
                            ).toLocaleDateString()}
                          </div>
                          <div className="text-xs text-neutral-500 dark:text-neutral-400">
                            {new Date(
                              deployment.inserted_at,
                            ).toLocaleTimeString()}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell className="py-3 text-right">
                        <div className="flex items-center justify-end gap-1">
                          <Button
                            size="sm"
                            variant="ghost"
                            asChild
                            className="h-7 w-7 p-0 hover:bg-neutral-100 dark:hover:bg-neutral-800"
                          >
                            <Link href={`/deployments/${deployment.id}`}>
                              <Eye className="h-3 w-3" />
                            </Link>
                          </Button>
                          {deployment.status === 'pending' && (
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-7 w-7 p-0 text-green-600 hover:bg-green-50 dark:hover:bg-green-950"
                              title="Deploy"
                              asChild
                            >
                              <Link
                                href={`/deployments/${deployment.id}/deploy`}
                                method="post"
                              >
                                <Play className="h-3 w-3" />
                              </Link>
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="ghost"
                            className="h-7 w-7 p-0 text-red-600 hover:bg-red-50 dark:hover:bg-red-950"
                            title="Delete deployment"
                            asChild
                          >
                            <Link
                              href={`/deployments/${deployment.id}`}
                              method="delete"
                            >
                              <Trash2 className="h-3 w-3" />
                            </Link>
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
    </Layout>
  );
}
