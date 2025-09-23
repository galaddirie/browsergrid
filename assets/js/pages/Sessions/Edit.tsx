import { useState } from 'react';
import { Link, router } from '@inertiajs/react';
import { ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import Layout from '@/components/Layout';
import { SessionForm } from '@/components/SessionForm';
import { Session, SessionEditProps } from '@/types';

export default function EditSession({ session, errors = {} }: SessionEditProps) {
  const [sessionData, setSessionData] = useState<Partial<Session>>(session);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    setIsLoading(true);
    
    router.put(`/sessions/${session.id}`, { session: sessionData }, {
      onFinish: () => setIsLoading(false),
      onError: (errors) => {
        console.error('Failed to update session:', errors);
      },
    });
  };

  const handleCancel = () => {
    router.visit(`/sessions/${session.id}`);
  };

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
            <h1 className="text-2xl font-semibold text-neutral-900 tracking-tight">
              Edit Session
            </h1>
            <p className="text-sm text-neutral-600 mt-1">
              Update your browser session settings
            </p>
          </div>
        </div>

        {/* Session Form */}
        <div className="max-w-4xl">
          <SessionForm
            session={sessionData}
            onSessionChange={setSessionData}
            onSubmit={handleSubmit}
            onCancel={handleCancel}
            isLoading={isLoading}
          />
        </div>

        {/* Error Display */}
        {Object.keys(errors).length > 0 && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <h3 className="text-sm font-medium text-red-800 mb-2">Please fix the following errors:</h3>
            <div className="list-disc list-inside text-sm text-red-700 space-y-1">
              {Object.entries(errors).map(([field, message]) => (
                <div key={field} className="ml-4">• {message}</div>
              ))}
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}
