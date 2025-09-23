import React from 'react';
import { Link } from '@inertiajs/react';
import { Plus, Package, Play, Trash2, Eye } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import Layout from '@/components/Layout';
import { useSetHeader } from '@/components/HeaderPortal';

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
    <Badge className={`${getStatusColor(status)} border-0`}>
      {status}
    </Badge>
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

export default function DeploymentsIndex({ deployments, total }: { deployments: Deployment[], total: number }) {
  useSetHeader({
    title: 'Deployments',
    description: 'Manage and deploy your browser automation projects',
    actions: (
      <Button size="sm" className="bg-neutral-900 hover:bg-neutral-800 text-white text-xs h-8" asChild>
        <Link href="/deployments/new">
          <Plus className="h-3 w-3 mr-1.5" />
          New Deployment
        </Link>
      </Button>
    )
  });

  const stats = {
    total: total || 0,
    running: deployments?.filter((d: Deployment) => ['running', 'deploying'].includes(d.status)).length || 0,
    pending: deployments?.filter((d: Deployment) => d.status === 'pending').length || 0,
    failed: deployments?.filter((d: Deployment) => ['failed', 'error'].includes(d.status)).length || 0,
  };

  return (
    <Layout>
      <div className="space-y-6">


        {/* Stats */}
        {deployments && deployments.length > 0 && (
          <div className="flex items-center gap-6 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">Total:</span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">{stats.total}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">Running:</span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">{stats.running}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">Pending:</span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">{stats.pending}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600 dark:text-neutral-400">Failed:</span>
              <span className="font-semibold text-neutral-900 dark:text-neutral-100">{stats.failed}</span>
            </div>
          </div>
        )}

        {/* Deployments Table */}
        <Card className="border-neutral-200/60 dark:border-neutral-800 p-0">
          <CardHeader className="flex flex-row items-center justify-between border-b border-neutral-100 dark:border-neutral-800 bg-neutral-50/30 dark:bg-neutral-900/30 py-3">
            <CardTitle className="text-base">Deployments</CardTitle>
          </CardHeader>
          <CardContent className="p-0 pt-0">
            {!deployments || deployments.length === 0 ? (
              <div className="text-center py-12">
                <Package className="h-8 w-8 mx-auto text-neutral-400 mb-3" />
                <h3 className="text-sm font-semibold text-neutral-900 dark:text-neutral-100 mb-1">No deployments yet</h3>
                <p className="text-xs text-neutral-600 dark:text-neutral-400 mb-4">
                  Get started by creating your first deployment.
                </p>
                <Button size="sm" className="bg-neutral-900 hover:bg-neutral-800 text-white text-xs h-8" asChild>
                  <Link href="/deployments/new">
                    <Plus className="h-3 w-3 mr-1.5" />
                    Create Deployment
                  </Link>
                </Button>
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow className="border-neutral-100 dark:border-neutral-800">
                    <TableHead className="font-medium text-neutral-700 dark:text-neutral-300 text-xs h-10">Name</TableHead>
                    <TableHead className="font-medium text-neutral-700 dark:text-neutral-300 text-xs h-10">Status</TableHead>
                    <TableHead className="font-medium text-neutral-700 dark:text-neutral-300 text-xs h-10">Last Deployed</TableHead>
                    <TableHead className="font-medium text-neutral-700 dark:text-neutral-300 text-xs h-10">Created</TableHead>
                    <TableHead className="text-right font-medium text-neutral-700 dark:text-neutral-300 text-xs h-10">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {deployments.map((deployment: Deployment) => (
                    <TableRow key={deployment.id} className="border-neutral-100 dark:border-neutral-800 hover:bg-neutral-50/50 dark:hover:bg-neutral-900/50 transition-colors duration-150">
                      <TableCell className="py-3">
                        <div className="space-y-0.5">
                          <div className="font-medium text-neutral-900 dark:text-neutral-100 text-sm">
                            {deployment.name}
                          </div>
                          {deployment.description && (
                            <div className="text-xs text-neutral-500 dark:text-neutral-400 truncate max-w-[200px]">
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
                            ? new Date(deployment.last_deployed_at).toLocaleDateString()
                            : 'Never'
                          }
                        </div>
                      </TableCell>
                      <TableCell className="py-3">
                        <div className="space-y-0.5">
                          <div className="text-xs text-neutral-900 dark:text-neutral-100">
                            {new Date(deployment.inserted_at).toLocaleDateString()}
                          </div>
                          <div className="text-xs text-neutral-500 dark:text-neutral-400">
                            {new Date(deployment.inserted_at).toLocaleTimeString()}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell className="text-right py-3">
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
                              <Link href={`/deployments/${deployment.id}/deploy`} method="post">
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
                            <Link href={`/deployments/${deployment.id}`} method="delete">
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