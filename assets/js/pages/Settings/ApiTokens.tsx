import React, { useEffect, useState } from 'react';

import { router, useForm, usePage } from '@inertiajs/react';
import { toast } from 'sonner';

import { Header } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface Token {
  id: string;
  name: string;
  prefix: string;
  created_at: string;
  last_used_at: string | null;
  expires_at: string | null;
}

interface TokenForm {
  name?: string;
  expires_at?: string | null;
}

interface PageProps {
  tokens?: Token[];
  generated_token?: string | null;
  errors?: Record<string, string[]>;
  form?: TokenForm;
}

const localeFormatter = new Intl.DateTimeFormat(undefined, {
  dateStyle: 'medium',
  timeStyle: 'short',
});

const formatDate = (value: string | null) => {
  if (!value) {
    return '—';
  }

  try {
    return localeFormatter.format(new Date(value));
  } catch (_err) {
    return value;
  }
};

const APIDialog = ({
  isCreateOpen,
  setIsCreateOpen,
  form,
  onSubmit,
}: {
  isCreateOpen: boolean;
  setIsCreateOpen: (open: boolean) => void;
  form: any;
  onSubmit: (event: React.FormEvent<HTMLFormElement>) => void;
}) => {
  return (
    <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
      <DialogTrigger asChild>
        <Button onClick={() => setIsCreateOpen(true)}>Create Token</Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>New API Token</DialogTitle>
          <DialogDescription>
            API tokens authenticate requests to the Browsergrid API. Provide a
            descriptive name and optional expiration date.
          </DialogDescription>
        </DialogHeader>

        <form className="space-y-4" onSubmit={onSubmit}>
          <div className="space-y-2">
            <Label htmlFor="token-name">Token Name</Label>
            <Input
              id="token-name"
              placeholder="Production automation"
              value={form.data.name}
              onChange={event => form.setData('name', event.target.value)}
              autoFocus
            />
            {form.errors.name && (
              <p className="text-sm text-red-500">{form.errors.name}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="token-expires">Expiration (optional)</Label>
            <Input
              id="token-expires"
              type="datetime-local"
              value={form.data.expires_at ?? ''}
              onChange={event => form.setData('expires_at', event.target.value)}
            />
            {form.errors.expires_at && (
              <p className="text-sm text-red-500">{form.errors.expires_at}</p>
            )}
            <p className="text-muted-foreground text-xs">
              Leave empty for a non-expiring token. Expired tokens cannot be
              used to access the API.
            </p>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                setIsCreateOpen(false);
                form.reset();
              }}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={form.processing}>
              {form.processing ? 'Creating…' : 'Create Token'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default function ApiTokensPage() {
  const { props } = usePage<{ props: PageProps }>();
  const tokens = (props.tokens ?? []) as Token[];
  const formDefaults = (props.form ?? {}) as TokenForm;
  const generatedToken = (props.generated_token ?? null) as string | null;

  const form = useForm<{
    name: string;
    expires_at: string;
  }>({
    name: formDefaults.name ?? '',
    expires_at: formDefaults.expires_at ?? '',
  });

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isRevealOpen, setIsRevealOpen] = useState(Boolean(generatedToken));
  const [revokeTarget, setRevokeTarget] = useState<Token | null>(null);

  useEffect(() => {
    form.setData({
      name: formDefaults.name ?? '',
      expires_at: formDefaults.expires_at ?? '',
    });
  }, [formDefaults.name, formDefaults.expires_at]);

  useEffect(() => {
    if (generatedToken) {
      setIsRevealOpen(true);
    }
  }, [generatedToken]);

  const onSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post('/settings/api', {
      preserveScroll: true,
      onSuccess: () => {
        setIsCreateOpen(false);
        form.reset();
      },
    });
  };

  const handleCopy = async () => {
    if (!generatedToken || typeof generatedToken !== 'string') return;

    try {
      await navigator.clipboard.writeText(generatedToken);
      toast.success('Token copied to clipboard');
    } catch (_error) {
      toast.error('Unable to copy token. Please copy manually.');
    }
  };

  const confirmRevoke = () => {
    if (!revokeTarget) return;

    router.delete(`/settings/api/${revokeTarget.id}`, {
      preserveScroll: true,
      onFinish: () => setRevokeTarget(null),
    });
  };

  return (
    <Layout>
      <Header>
        <div className="flex w-full flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="mb-2 text-4xl font-bold">API Tokens</h1>
            <p className="text-primary/70 text-sm">
              Generate personal access tokens for integrating with the
              Browsergrid API.
            </p>
          </div>
          <APIDialog
            isCreateOpen={isCreateOpen}
            setIsCreateOpen={setIsCreateOpen}
            form={form}
            onSubmit={onSubmit}
          />
        </div>
      </Header>

      <div className="space-y-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0">
            <div>
              <CardTitle className="text-lg font-semibold">
                Active tokens
              </CardTitle>
              <p className="text-muted-foreground text-sm">
                Tokens are hashed at rest. You can only view the full token
                once.
              </p>
            </div>
          </CardHeader>
          <CardContent>
            {tokens.length === 0 ? (
              <div className="flex flex-col items-center justify-center rounded-lg border border-dashed p-8 text-center">
                <h3 className="text-lg font-semibold">No tokens yet</h3>
                <p className="text-muted-foreground mt-1 text-sm">
                  Create your first API token to start making authenticated API
                  requests.
                </p>
                <Button className="mt-4" onClick={() => setIsCreateOpen(true)}>
                  Create Token
                </Button>
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Prefix</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead>Last used</TableHead>
                    <TableHead>Expires</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {tokens.map(token => (
                    <TableRow key={token.id}>
                      <TableCell className="font-medium">
                        {token.name}
                      </TableCell>
                      <TableCell>
                        <span className="bg-muted rounded px-2 py-1 font-mono text-xs">
                          {token.prefix}
                        </span>
                      </TableCell>
                      <TableCell>{formatDate(token.created_at)}</TableCell>
                      <TableCell>
                        {token.last_used_at
                          ? formatDate(token.last_used_at)
                          : 'Never'}
                      </TableCell>
                      <TableCell>
                        {token.expires_at
                          ? formatDate(token.expires_at)
                          : 'No expiration'}
                      </TableCell>
                      <TableCell className="text-right">
                        <Button
                          variant="destructive"
                          size="sm"
                          onClick={() => setRevokeTarget(token)}
                        >
                          Revoke
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>

      <Dialog
        open={isRevealOpen && Boolean(generatedToken)}
        onOpenChange={setIsRevealOpen}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Your new API token</DialogTitle>
            <DialogDescription>
              This token is only shown once. Copy it now and store it securely.
            </DialogDescription>
          </DialogHeader>

          <div className="bg-muted/60 rounded-md border p-4">
            <code className="block font-mono text-sm break-all whitespace-pre-wrap">
              {generatedToken}
            </code>
          </div>

          <p className="text-muted-foreground text-xs">
            Treat this token like a password. Anyone with this token can access
            your Browsergrid data.
          </p>

          <DialogFooter className="mt-4">
            <Button variant="outline" onClick={() => setIsRevealOpen(false)}>
              Close
            </Button>
            <Button onClick={handleCopy}>Copy token</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={Boolean(revokeTarget)}
        onOpenChange={open => !open && setRevokeTarget(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Revoke token</DialogTitle>
            <DialogDescription>
              Revoking <span className="font-medium">{revokeTarget?.name}</span>{' '}
              will immediately prevent it from accessing the API. This action
              cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRevokeTarget(null)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={confirmRevoke}>
              Revoke Token
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Layout>
  );
}
