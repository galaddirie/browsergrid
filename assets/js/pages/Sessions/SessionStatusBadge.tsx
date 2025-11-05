import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

import { sessionStatusTone } from './utils';

interface SessionStatusBadgeProps {
  status?: string | null;
  className?: string;
}

export function SessionStatusBadge({
  status,
  className,
}: SessionStatusBadgeProps) {
  return (
    <Badge className={cn(sessionStatusTone(status), 'border-0', className)}>
      {status ?? 'unknown'}
    </Badge>
  );
}

