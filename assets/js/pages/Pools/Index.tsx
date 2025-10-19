import { Link } from '@inertiajs/react';
import {
  AlertTriangle,
  BarChart3,
  CheckCircle2,
  Layers,
  Plus,
  Users,
} from 'lucide-react';

import Layout from '@/components/Layout';
import { Header } from '@/components/HeaderPortal';
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
import {
  SessionPoolStatistics,
  SessionPoolSummary,
} from '@/types';

interface PoolsIndexProps {
  pools: SessionPoolSummary[];
  summary: {
    total: number;
    ready: number;
    claimed: number;
    running: number;
    errored: number;
  };
}

const HealthBadge = ({ health }: { health: string }) => {
  const normalized = health?.toLowerCase();
  switch (normalized) {
    case 'healthy':
      return (
        <Badge className="bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200">
          Healthy
        </Badge>
      );
    case 'scaling':
    case 'warming':
      return (
        <Badge className="bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200">
          Warming
        </Badge>
      );
    case 'degraded':
      return (
        <Badge className="bg-rose-100 text-rose-800 dark:bg-rose-900 dark:text-rose-200">
          Degraded
        </Badge>
      );
    default:
      return (
        <Badge className="bg-slate-100 text-slate-800 dark:bg-slate-900 dark:text-slate-200">
          Idle
        </Badge>
      );
  }
};

const formatCounts = (statistics: SessionPoolStatistics) => {
  return [
    `${statistics.ready} ready`,
    `${statistics.warming} warming`,
    `${statistics.claimed} claimed`,
  ].join(' · ');
};

export default function PoolsIndex({ pools, summary }: PoolsIndexProps) {
  return (
    <Layout>
      <Header>
        <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 className="mb-2 text-4xl font-bold">Session Pools</h1>
            <p className="text-primary/70 mb-6 text-sm">
              Prewarm sessions for instant availability, with visibility and
              lifecycle controls.
            </p>
            <Button
              asChild
              className="bg-neutral-900 text-white hover:bg-neutral-800"
              size="sm"
            >
              <Link href="/pools/new">
                <Plus className="mr-2 h-4 w-4" />
                New Pool
              </Link>
            </Button>
          </div>

        </div>
      </Header>

      <div className="space-y-6">
        <div className="grid gap-4 md:grid-cols-4">
          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60 pb-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">
                Total Pools
              </p>
            </CardHeader>
            <CardContent className="flex items-center gap-3 py-4">
              <Layers className="h-8 w-8 text-neutral-400" />
              <div>
                <p className="text-2xl font-bold text-neutral-900">
                  {summary.total}
                </p>
                <p className="text-xs text-neutral-500">
                  {summary.total === 1 ? 'pool' : 'pools'} configured
                </p>
              </div>
            </CardContent>
          </Card>

          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60 pb-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">
                Ready Capacity
              </p>
            </CardHeader>
            <CardContent className="flex items-center gap-3 py-4">
              <CheckCircle2 className="h-8 w-8 text-emerald-500" />
              <div>
                <p className="text-2xl font-bold text-neutral-900">
                  {summary.ready}
                </p>
                <p className="text-xs text-neutral-500">
                  sessions prewarmed across all pools
                </p>
              </div>
            </CardContent>
          </Card>

          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60 pb-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">
                Claimed & Running
              </p>
            </CardHeader>
            <CardContent className="flex items-center gap-3 py-4">
              <Users className="h-8 w-8 text-blue-500" />
              <div>
                <p className="text-2xl font-bold text-neutral-900">
                  {summary.claimed + summary.running}
                </p>
                <p className="text-xs text-neutral-500">
                  in use ({summary.claimed} claimed / {summary.running} running)
                </p>
              </div>
            </CardContent>
          </Card>

          <Card className="border-neutral-200/60">
            <CardHeader className="bg-neutral-50/60 pb-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">
                Attention Needed
              </p>
            </CardHeader>
            <CardContent className="flex items-center gap-3 py-4">
              <AlertTriangle className="h-8 w-8 text-amber-500" />
              <div>
                <p className="text-2xl font-bold text-neutral-900">
                  {summary.errored}
                </p>
                <p className="text-xs text-neutral-500">
                  sessions failed across pools
                </p>
              </div>
            </CardContent>
          </Card>
        </div>

        <Card className="border-neutral-200/60">
          <CardHeader className="flex flex-row items-center justify-between bg-neutral-50/60">
            <CardTitle className="flex items-center gap-2 text-base font-semibold text-neutral-700">
              <BarChart3 className="h-5 w-5 text-neutral-500" />
              Pool Inventory
            </CardTitle>
            <p className="text-xs text-neutral-500">
              Visibility, owners, ready capacity, health, and live status
            </p>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[220px]">Pool</TableHead>
                  <TableHead>Visibility</TableHead>
                  <TableHead>Owner</TableHead>
                  <TableHead>Capacity</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Health</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {pools.length === 0 && (
                  <TableRow>
                    <TableCell
                      colSpan={7}
                      className="py-12 text-center text-sm text-neutral-500"
                    >
                      No pools yet. Create one to keep sessions warm for instant
                      testing.
                    </TableCell>
                  </TableRow>
                )}

                {pools.map(pool => (
                  <TableRow key={pool.id} className="hover:bg-neutral-50/50">
                    <TableCell className="py-4">
                      <div className="space-y-1">
                        <div className="text-sm font-semibold text-neutral-900">
                          {pool.name}
                        </div>
                        {pool.description && (
                          <p className="text-xs text-neutral-500">
                            {pool.description}
                          </p>
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="py-4">
                      <Badge
                        variant="outline"
                        className="border-neutral-200 text-xs capitalize text-neutral-600"
                      >
                        {pool.visibility}
                      </Badge>
                    </TableCell>
                    <TableCell className="py-4 text-sm text-neutral-700">
                      {pool.owner?.email || (pool.system ? 'Platform' : '—')}
                    </TableCell>
                    <TableCell className="py-4 text-sm text-neutral-700">
                      {pool.min} min / {pool.max === 0 ? 'unlimited' : pool.max} max
                    </TableCell>
                    <TableCell className="py-4 text-xs text-neutral-600">
                      {formatCounts(pool.statistics)}
                    </TableCell>
                    <TableCell className="py-4">
                      <HealthBadge health={pool.health} />
                    </TableCell>
                    <TableCell className="py-4 text-right">
                      <Button asChild size="sm" variant="outline">
                        <Link href={`/pools/${pool.id}`}>View Details</Link>
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </Layout>
  );
}
