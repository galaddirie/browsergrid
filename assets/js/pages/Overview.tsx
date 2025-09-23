import React from 'react';
import { Globe, Layers, Activity, Package } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import Layout from '@/components/Layout';
import { Header } from '@/components/HeaderPortal';

export default function Overview({ stats, sessions }: { stats: any, sessions: any }) {
  const statsCards = [
    {
      title: 'Active Sessions',
      value: stats.active_sessions,
      total: stats.total_sessions,
      icon: Globe,
      color: 'text-blue-600'
    },
    {
      title: 'Available Sessions',
      value: stats.available_sessions,
      total: stats.total_sessions,
      icon: Layers,
      color: 'text-green-600'
    },
    {
      title: 'Failed Sessions',
      value: stats.failed_sessions,
      total: stats.total_sessions,
      icon: Activity,
      color: 'text-red-600'
    },
    {
      title: 'Total Sessions',
      value: stats.total_sessions,
      total: stats.total_sessions,
      icon: Package,
      color: 'text-purple-600'
    },
  ];

  return (
    <Layout>
      <Header>
        <div>
          <h1 className="mb-2 text-4xl font-bold">Overview</h1>
          <p className="text-primary/70 mb-6 text-sm">
            Monitor your browser infrastructure at a glance
          </p>
        </div>
      </Header>
      <div className="space-y-6">

        
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-4">
          {statsCards.map((stat, index) => (
            <Card key={index}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{stat.title}</CardTitle>
                <stat.icon className={`h-4 w-4 ${stat.color}`} />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stat.value}</div>
                <p className="text-xs text-muted-foreground">
                  of {stat.total} total
                </p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Recent Sessions */}
        {sessions && sessions.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Recent Sessions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {sessions.map((session) => (
                  <div key={session.id} className="flex items-center justify-between p-2 border rounded">
                    <div>
                      <div className="font-medium">{session.id?.substring(0, 8)}...</div>
                      <div className="text-sm text-muted-foreground">
                        {session.browser} {session.version} • {session.operating_system}
                      </div>
                    </div>
                    <div className="text-sm">
                      <span className={`px-2 py-1 rounded text-xs ${
                        session.status === 'running' ? 'bg-green-100 text-green-800' :
                        session.status === 'available' ? 'bg-blue-100 text-blue-800' :
                        'bg-gray-100 text-gray-800'
                      }`}>
                        {session.status}
                      </span>
                    </div>
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