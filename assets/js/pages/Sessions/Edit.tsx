import { useState } from 'react';

import { Link, router } from '@inertiajs/react';
import { ArrowLeft } from 'lucide-react';

import Layout from '@/components/Layout';
import { SessionForm } from '@/pages/Sessions/form';
import { Button } from '@/components/ui/button';
import {
  formDataToSession,
  SessionEditProps,
  SessionFormData,
  sessionToFormData,
} from '@/types';

export default function EditSession({
  session,
  errors = {},
}: SessionEditProps) {
  const [sessionData, setSessionData] = useState<Partial<SessionFormData>>(
    sessionToFormData(session),
  );

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center gap-4">
          <Button asChild variant="ghost" size="sm" className="h-8 w-8 p-0">
            <Link href={`/sessions/${session.id}`}>
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-2xl font-semibold tracking-tight text-neutral-900">
              Edit Session
            </h1>
            <p className="mt-1 text-sm text-neutral-600">
              Update your browser session settings
            </p>
          </div>
        </div>

        {/* Session Form */}
        <div className="max-w-4xl">
          <SessionForm session={sessionData} onSessionChange={setSessionData} />
        </div>

        {/* Error Display */}
        {Object.keys(errors).length > 0 && (
          <div className="rounded-lg border border-red-200 bg-red-50 p-4">
            <h3 className="mb-2 text-sm font-medium text-red-800">
              Please fix the following errors:
            </h3>
            <div className="list-inside list-disc space-y-1 text-sm text-red-700">
              {Object.entries(errors).map(([field, message]) => (
                <div key={field} className="ml-4">
                  • {message}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex max-w-4xl justify-between gap-2 border-t pt-6">
          <Button variant="outline" asChild>
            <Link href={`/sessions/${session.id}`}>Cancel</Link>
          </Button>
          <Button
            onClick={() => {
              const backendData = formDataToSession(sessionData);
              const payload: Record<string, unknown> = {
                name: backendData.name,
                browser_type: backendData.browser_type,
                profile_id: backendData.profile_id,
                headless: backendData.headless,
                timeout: backendData.timeout,
                ttl_seconds: backendData.ttl_seconds,
                cluster: backendData.cluster,
                session_pool_id: backendData.session_pool_id,
              };

              if (backendData.screen) {
                payload.screen = backendData.screen;
              }

              if (backendData.limits) {
                payload.limits = backendData.limits;
              }

              Object.keys(payload).forEach(key => {
                if (payload[key] === undefined) {
                  delete payload[key];
                }
              });

              router.put(`/sessions/${session.id}`, { session: payload });
            }}
          >
            Save Changes
          </Button>
        </div>
      </div>
    </Layout>
  );
}
