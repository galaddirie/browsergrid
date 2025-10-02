import React from 'react';

import { AlertCircle, CheckCircle, Loader2,XCircle } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

interface ApiStatusProps {
  status: 'connected' | 'disconnected' | 'loading' | 'error';
  message?: string;
  endpoint?: string;
}

export default function ApiStatus({ status, message, endpoint }: ApiStatusProps) {
  const getStatusIcon = () => {
    switch (status) {
      case 'connected':
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'disconnected':
        return <XCircle className="h-4 w-4 text-red-500" />;
      case 'loading':
        return <Loader2 className="h-4 w-4 text-blue-500 animate-spin" />;
      case 'error':
        return <AlertCircle className="h-4 w-4 text-orange-500" />;
      default:
        return <AlertCircle className="h-4 w-4 text-gray-500" />;
    }
  };

  const getStatusColor = () => {
    switch (status) {
      case 'connected':
        return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
      case 'disconnected':
        return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
      case 'loading':
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
      case 'error':
        return 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200';
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
    }
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-medium">API Status</CardTitle>
          {getStatusIcon()}
        </div>
        {endpoint && (
          <CardDescription className="text-xs">
            {endpoint}
          </CardDescription>
        )}
      </CardHeader>
      <CardContent>
        <div className="flex items-center gap-2">
          <Badge className={`${getStatusColor()} border-0 text-xs`}>
            {status.charAt(0).toUpperCase() + status.slice(1)}
          </Badge>
          {message && (
            <span className="text-sm text-muted-foreground">{message}</span>
          )}
        </div>
        {status === 'connected' && (
          <div className="mt-2 text-xs text-muted-foreground">
            ✓ Ready to create sessions with defaults:
            <br />• Chrome latest on Linux
            <br />• 1920x1080 resolution
            <br />• 2 CPU cores, 2GB RAM
            <br />• 30 minute timeout
          </div>
        )}
      </CardContent>
    </Card>
  );
} 