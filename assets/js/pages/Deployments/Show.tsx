import { Link } from '@inertiajs/react';
import { ArrowLeft, ExternalLink, Play, Trash2 } from 'lucide-react';

import Layout from '@/components/Layout';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

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

export default function DeploymentShow({ deployment }: { deployment: any }) {
  const canDeploy =
    deployment.status === 'pending' || deployment.status === 'stopped';

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button asChild variant="ghost" size="sm" className="h-8 w-8 p-0">
              <Link href="/deployments">
                <ArrowLeft className="h-4 w-4" />
              </Link>
            </Button>
            <div>
              <h1 className="text-2xl font-semibold tracking-tight text-neutral-900 dark:text-neutral-100">
                {deployment.name}
              </h1>
              <p className="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
                {deployment.description || 'No description provided'}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {canDeploy && (
              <Button
                size="sm"
                className="h-8 bg-green-600 text-xs text-white hover:bg-green-700"
                asChild
              >
                <Link
                  href={`/deployments/${deployment.id}/deploy`}
                  method="post"
                >
                  <Play className="mr-1.5 h-3 w-3" />
                  Deploy
                </Link>
              </Button>
            )}
            {deployment.session_id && (
              <Button
                size="sm"
                variant="outline"
                className="h-8 text-xs"
                asChild
              >
                <Link href={`/sessions/${deployment.session_id}`}>
                  <ExternalLink className="mr-1.5 h-3 w-3" />
                  View Session
                </Link>
              </Button>
            )}
            <Button
              size="sm"
              variant="destructive"
              className="h-8 text-xs"
              asChild
            >
              <Link href={`/deployments/${deployment.id}`} method="delete">
                <Trash2 className="mr-1.5 h-3 w-3" />
                Delete
              </Link>
            </Button>
          </div>
        </div>

        {/* Deployment Details Content */}
        <div className="grid gap-4 md:grid-cols-2">
          <Card className="border-neutral-200 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                Deployment Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600 dark:text-neutral-400">
                  ID
                </span>
                <span className="font-mono text-xs text-neutral-900 dark:text-neutral-100">
                  {deployment.id}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600 dark:text-neutral-400">
                  Status
                </span>
                <StatusBadge status={deployment.status} />
              </div>
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600 dark:text-neutral-400">
                  Created
                </span>
                <span className="text-xs text-neutral-900 dark:text-neutral-100">
                  {new Date(deployment.inserted_at).toLocaleString()}
                </span>
              </div>
              {deployment.last_deployed_at && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600 dark:text-neutral-400">
                    Last Deployed
                  </span>
                  <span className="text-xs text-neutral-900 dark:text-neutral-100">
                    {new Date(deployment.last_deployed_at).toLocaleString()}
                  </span>
                </div>
              )}
              {deployment.session_id && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600 dark:text-neutral-400">
                    Session ID
                  </span>
                  <span className="font-mono text-xs text-neutral-900 dark:text-neutral-100">
                    {deployment.session_id.slice(0, 8)}...
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          <Card className="border-neutral-200 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                Configuration
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600 dark:text-neutral-400">
                  Root Directory
                </span>
                <span className="font-mono text-xs text-neutral-900 dark:text-neutral-100">
                  {deployment.root_directory}
                </span>
              </div>
              {deployment.install_command && (
                <div className="flex justify-between py-1">
                  <span className="text-xs text-neutral-600 dark:text-neutral-400">
                    Install Command
                  </span>
                  <span className="max-w-[200px] truncate font-mono text-xs text-neutral-900 dark:text-neutral-100">
                    {deployment.install_command}
                  </span>
                </div>
              )}
              <div className="flex justify-between py-1">
                <span className="text-xs text-neutral-600 dark:text-neutral-400">
                  Start Command
                </span>
                <span className="max-w-[200px] truncate font-mono text-xs text-neutral-900 dark:text-neutral-100">
                  {deployment.start_command}
                </span>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Environment Variables */}
        {deployment.environment_variables &&
          deployment.environment_variables.length > 0 && (
            <Card className="border-neutral-200 dark:border-neutral-800">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                  Environment Variables
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-2">
                  {deployment.environment_variables.map(
                    (env: any, index: number) => (
                      <div
                        key={index}
                        className="flex items-center justify-between py-1"
                      >
                        <span className="font-mono text-xs text-neutral-600 dark:text-neutral-400">
                          {env.key}
                        </span>
                        <span className="max-w-[200px] truncate font-mono text-xs text-neutral-900 dark:text-neutral-100">
                          {env.value}
                        </span>
                      </div>
                    ),
                  )}
                </div>
              </CardContent>
            </Card>
          )}

        {/* Parameters */}
        {deployment.parameters && deployment.parameters.length > 0 && (
          <Card className="border-neutral-200 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                Parameters
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid gap-3">
                {deployment.parameters.map((parameter: any, index: number) => (
                  <div
                    key={index}
                    className="rounded-lg border bg-neutral-50 p-3 dark:bg-neutral-900"
                  >
                    <div className="mb-1 flex items-center justify-between">
                      <span className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                        {parameter.label}
                      </span>
                      <span className="font-mono text-xs text-neutral-600 dark:text-neutral-400">
                        {parameter.key}
                      </span>
                    </div>
                    {parameter.description && (
                      <p className="text-xs text-neutral-600 dark:text-neutral-400">
                        {parameter.description}
                      </p>
                    )}
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </Layout>
  );
}
