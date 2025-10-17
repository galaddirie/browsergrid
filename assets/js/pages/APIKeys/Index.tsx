import React, { useEffect, useMemo, useState } from "react";

import { router } from "@inertiajs/react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import Layout from "@/components/Layout";
import { useSetHeader } from "@/components/HeaderPortal";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Copy, KeyRound, Lock, Plus, RefreshCw, Shield, Trash2 } from "lucide-react";

interface ApiKey {
  id: string;
  name: string;
  prefix: string;
  lastFour: string;
  displayHint: string;
  status: "active" | "revoked" | "expired" | string;
  createdBy?: string | null;
  metadata: Record<string, any> | null;
  usageCount: number;
  insertedAt?: string | null;
  updatedAt?: string | null;
  revokedAt?: string | null;
  expiresAt?: string | null;
  lastUsedAt?: string | null;
}

interface Stats {
  total: number;
  active: number;
  revoked: number;
  expired: number;
}

interface PageProps {
  api_keys: ApiKey[];
  stats: Stats;
  new_token?: { value: string; api_key: ApiKey } | null;
  regenerated?: { token: string; api_key: ApiKey; previous: ApiKey } | null;
  revoked?: ApiKey | null;
  errors?: Record<string, string | string[]> | null;
}

const statusStyles: Record<string, string> = {
  active: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200",
  expired: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
  revoked: "bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-200"
};

const formatDate = (value?: string | null) => {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return `${date.toLocaleDateString()} ${date.toLocaleTimeString()}`;
};

const StatusBadge = ({ status }: { status: string }) => (
  <Badge className={`${statusStyles[status] ?? "bg-neutral-200 text-neutral-700"} border-0 text-[11px] px-2 py-1`}>{status}</Badge>
);

const CopyButton = ({ value, label }: { value: string; label?: string }) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch (error) {
      console.error("Unable to copy token", error);
    }
  };

  return (
    <Button variant="outline" size="sm" onClick={handleCopy} className="gap-2">
      <Copy className="h-3.5 w-3.5" />
      {copied ? "Copied" : label ?? "Copy"}
    </Button>
  );
};

const Snippet = ({ title, description, code, language }: { title: string; description: string; code: string; language: string }) => (
  <Card className="border-neutral-200/70 dark:border-neutral-800">
    <CardHeader>
      <CardTitle className="text-sm font-semibold flex items-center gap-2">
        <Shield className="h-4 w-4 text-neutral-500" />
        {title}
      </CardTitle>
      <p className="text-xs text-neutral-500">{description}</p>
    </CardHeader>
    <CardContent>
      <pre className="bg-neutral-950 text-neutral-50 rounded-lg text-xs p-4 overflow-auto" id={`snippet-${language}`}>
        <code>{code}</code>
      </pre>
    </CardContent>
  </Card>
);

export default function APIKeysIndex({ api_keys, stats, new_token, regenerated, revoked, errors }: PageProps) {
  const [isCreateOpen, setCreateOpen] = useState(false);
  const [isRevealOpen, setRevealOpen] = useState(false);
  const [tokenPayload, setTokenPayload] = useState<{ value: string; apiKey: ApiKey; context: "created" | "regenerated" } | null>(null);
  const [regenerateTarget, setRegenerateTarget] = useState<ApiKey | null>(null);
  const [revokeTarget, setRevokeTarget] = useState<ApiKey | null>(null);
  const [formName, setFormName] = useState("");
  const [formExpiry, setFormExpiry] = useState<string>("");
  const [formErrors, setFormErrors] = useState<Record<string, string>>({});

  useSetHeader({
    title: "API Access",
    description: "Issue and manage scoped API keys for automation and integrations",
    actions: (
      <Button id="api-key-create-trigger" size="sm" className="bg-neutral-900 hover:bg-neutral-800 text-white" onClick={() => setCreateOpen(true)}>
        <Plus className="h-3.5 w-3.5 mr-2" />
        New Key
      </Button>
    )
  });

  useEffect(() => {
    if (new_token?.value && new_token.api_key) {
      setTokenPayload({ value: new_token.value, apiKey: new_token.api_key, context: "created" });
      setRevealOpen(true);
      setCreateOpen(false);
      setFormName("");
      setFormExpiry("");
    }
  }, [new_token]);

  useEffect(() => {
    if (regenerated?.token && regenerated.api_key) {
      setTokenPayload({ value: regenerated.token, apiKey: regenerated.api_key, context: "regenerated" });
      setRevealOpen(true);
      setRegenerateTarget(null);
    }
  }, [regenerated]);

  useEffect(() => {
    if (revoked) {
      setRevokeTarget(null);
    }
  }, [revoked]);

  useEffect(() => {
    const formatted: Record<string, string> = {};
    if (errors) {
      Object.entries(errors).forEach(([field, message]) => {
        if (Array.isArray(message)) {
          formatted[field] = message.join(" ");
        } else if (typeof message === "string") {
          formatted[field] = message;
        }
      });
      if (Object.keys(formatted).length > 0) {
        setCreateOpen(true);
      }
    }
    setFormErrors(formatted);
  }, [errors]);

  const handleCreate = () => {
    setFormErrors({});
    router.post("/api-keys", {
      api_key: {
        name: formName,
        expires_at: formExpiry || null
      }
    }, {
      preserveState: true,
      onError: (incomingErrors) => {
        const formatted: Record<string, string> = {};
        Object.entries(incomingErrors).forEach(([key, value]) => {
          formatted[key] = Array.isArray(value) ? value.join(" ") : (value as string);
        });
        setFormErrors(formatted);
      }
    });
  };

  const handleRegenerate = () => {
    if (!regenerateTarget) return;

    router.post(`/api-keys/${regenerateTarget.id}/regenerate`, {
      api_key: {
        name: regenerateTarget.name,
        expires_at: regenerateTarget.expiresAt
      }
    }, {
      preserveState: true
    });
  };

  const handleRevoke = () => {
    if (!revokeTarget) return;

    router.post(`/api-keys/${revokeTarget.id}/revoke`, {}, {
      preserveState: true
    });
  };

  const activeKeys = useMemo(() => api_keys.filter(key => key.status === "active"), [api_keys]);

  const snippets = useMemo(() => [
    {
      title: "HTTP Authorization Header",
      description: "Recommended: send tokens using the standard Bearer header",
      code: `curl https://api.browsergrid.com/api/v1/sessions \\\n  -H "Authorization: Bearer ${activeKeys[0]?.displayHint.replace("****", "{token}" ) || "bg_PREFIX_{token}"}"`,
      language: "curl"
    },
    {
      title: "JavaScript Fetch",
      description: "Attach the API key via Authorization header for browser or Node clients",
      code: `await fetch('https://api.browsergrid.com/api/v1/sessions', {
  headers: {
    Authorization: 'Bearer YOUR_API_KEY',
    'Content-Type': 'application/json'
  }
});`,
      language: "js"
    },
    {
      title: "Query Param Fallback",
      description: "Supported for legacy clients. Always prefer the Authorization header.",
      code: `GET https://api.browsergrid.com/api/v1/sessions?token=YOUR_API_KEY`,
      language: "query"
    }
  ], [activeKeys]);

  return (
    <Layout>
      <div className="space-y-8">
        <section className="grid gap-4 md:grid-cols-4" id="api-key-stats">
          <Card className="border-neutral-200/70 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs uppercase tracking-widest text-neutral-500">Total Keys</CardTitle>
            </CardHeader>
            <CardContent className="text-3xl font-semibold">{stats?.total ?? 0}</CardContent>
          </Card>
          <Card className="border-neutral-200/70 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs uppercase tracking-widest text-neutral-500">Active</CardTitle>
            </CardHeader>
            <CardContent className="text-3xl font-semibold text-emerald-600">{stats?.active ?? 0}</CardContent>
          </Card>
          <Card className="border-neutral-200/70 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs uppercase tracking-widest text-neutral-500">Revoked</CardTitle>
            </CardHeader>
            <CardContent className="text-3xl font-semibold text-rose-600">{stats?.revoked ?? 0}</CardContent>
          </Card>
          <Card className="border-neutral-200/70 dark:border-neutral-800">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs uppercase tracking-widest text-neutral-500">Expired</CardTitle>
            </CardHeader>
            <CardContent className="text-3xl font-semibold text-amber-600">{stats?.expired ?? 0}</CardContent>
          </Card>
        </section>

        <Card className="border-neutral-200/70 dark:border-neutral-800" id="api-key-table">
          <CardHeader className="flex flex-col gap-1 border-b border-neutral-100 dark:border-neutral-800">
            <CardTitle className="text-base font-semibold flex items-center gap-2">
              <KeyRound className="h-4 w-4" />
              API Keys
            </CardTitle>
            <p className="text-sm text-neutral-500">Each key is hashed at rest and can be revoked or rotated without downtime.</p>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="text-xs uppercase tracking-wide">Name</TableHead>
                  <TableHead className="text-xs uppercase tracking-wide">Token Preview</TableHead>
                  <TableHead className="text-xs uppercase tracking-wide">Usage</TableHead>
                  <TableHead className="text-xs uppercase tracking-wide">Last Used</TableHead>
                  <TableHead className="text-xs uppercase tracking-wide">Status</TableHead>
                  <TableHead className="text-right text-xs uppercase tracking-wide">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {api_keys.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} className="py-10 text-center text-sm text-neutral-500">
                      No API keys yet. Create your first key to enable programmatic access.
                    </TableCell>
                  </TableRow>
                )}
                {api_keys.map((apiKey) => (
                  <TableRow key={apiKey.id} className="hover:bg-neutral-50/60 dark:hover:bg-neutral-900/60">
                    <TableCell className="py-4">
                      <div className="flex flex-col">
                        <span className="font-medium text-sm text-neutral-900 dark:text-neutral-100">{apiKey.name}</span>
                        <span className="text-xs text-neutral-500">Created {formatDate(apiKey.insertedAt)}</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <span className="font-mono text-xs bg-neutral-100 dark:bg-neutral-900 px-2 py-1 rounded border border-neutral-200 dark:border-neutral-800">
                        {apiKey.displayHint}
                      </span>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm">
                        <span className="font-medium">{apiKey.usageCount}</span>
                        <span className="text-xs text-neutral-500 block">requests</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <span className="text-sm text-neutral-700 dark:text-neutral-300">{formatDate(apiKey.lastUsedAt)}</span>
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={apiKey.status} />
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Button
                          id={`api-key-regenerate-${apiKey.id}`}
                          variant="outline"
                          size="sm"
                          className="gap-2"
                          disabled={apiKey.status === "revoked"}
                          onClick={() => {
                            setRegenerateTarget(apiKey);
                          }}
                        >
                          <RefreshCw className="h-3.5 w-3.5" />
                          Rotate
                        </Button>
                        <Button
                          id={`api-key-revoke-${apiKey.id}`}
                          variant="ghost"
                          size="sm"
                          className="gap-2 text-rose-600 hover:text-rose-700"
                          disabled={apiKey.status === "revoked"}
                          onClick={() => setRevokeTarget(apiKey)}
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                          Revoke
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <section className="grid gap-4 md:grid-cols-3" id="api-key-guide">
          <Card className="border-neutral-200/70 dark:border-neutral-800">
            <CardHeader>
              <CardTitle className="text-sm flex items-center gap-2">
                <Lock className="h-4 w-4" />
                Operational Guidance
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-neutral-600 dark:text-neutral-400">
              <p>Keys are hashed with Argon2id. The raw value is displayed only once. Store it in a secure secret manager.</p>
              <p>Include the key in the <code className="bg-neutral-200/80 px-1.5 py-0.5 rounded font-mono text-xs">Authorization</code> header whenever possible.</p>
              <p>You can rotate keys anytime. The previous key is revoked immediately and cannot be recovered.</p>
            </CardContent>
          </Card>
          <Card className="border-neutral-200/70 dark:border-neutral-800 md:col-span-2">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">Integration Snippets</CardTitle>
              <p className="text-xs text-neutral-500">Reference examples for the most common integration patterns.</p>
            </CardHeader>
            <CardContent>
              <Tabs defaultValue="curl">
                <TabsList className="grid grid-cols-3">
                  <TabsTrigger value="curl">cURL</TabsTrigger>
                  <TabsTrigger value="js">JavaScript</TabsTrigger>
                  <TabsTrigger value="query">Query Param</TabsTrigger>
                </TabsList>
                {snippets.map(snippet => (
                  <TabsContent value={snippet.language} key={snippet.language}>
                    <Snippet {...snippet} />
                  </TabsContent>
                ))}
              </Tabs>
            </CardContent>
          </Card>
        </section>

        <Dialog open={isCreateOpen} onOpenChange={setCreateOpen}>
          <DialogContent id="api-key-create-dialog" className="sm:max-w-lg" aria-describedby="api-key-create-description">
            <DialogHeader>
              <DialogTitle>Create API Key</DialogTitle>
              <DialogDescription id="api-key-create-description">
                Choose a descriptive label and optional expiration date. The raw key will be revealed only once.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-2">
              <div className="space-y-2">
                <Label htmlFor="api-key-name">Name</Label>
                <Input
                  id="api-key-name"
                  value={formName}
                  onChange={(event) => setFormName(event.target.value)}
                  placeholder="Production automation"
                  className={formErrors.name ? "border-rose-500" : ""}
                />
                {formErrors.name && <p className="text-xs text-rose-600" id="api-key-name-error">{formErrors.name}</p>}
              </div>
              <div className="space-y-2">
                <Label htmlFor="api-key-expiry">Expires At (optional)</Label>
                <Input
                  id="api-key-expiry"
                  type="datetime-local"
                  value={formExpiry}
                  onChange={(event) => setFormExpiry(event.target.value)}
                />
                {formErrors.expires_at && <p className="text-xs text-rose-600">{formErrors.expires_at}</p>}
              </div>
              <Alert variant="default" className="bg-amber-50 border-amber-200 text-amber-900">
                <AlertTitle>Sensitive credential</AlertTitle>
                <AlertDescription>Store the generated key immediately — it will not be shown again.</AlertDescription>
              </Alert>
            </div>
            <DialogFooter className="flex justify-between">
              <Button variant="outline" onClick={() => setCreateOpen(false)}>Cancel</Button>
              <Button id="api-key-create-submit" onClick={handleCreate} className="bg-neutral-900 text-white">Create key</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <Dialog open={!!regenerateTarget} onOpenChange={(open) => !open && setRegenerateTarget(null)}>
          <DialogContent id="api-key-rotate-dialog" className="sm:max-w-md" aria-describedby="api-key-rotate-description">
            <DialogHeader>
              <DialogTitle>Rotate API Key</DialogTitle>
              <DialogDescription id="api-key-rotate-description">
                The current key will be revoked instantly. A new value will be generated and shown once.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-3">
              <p className="text-sm text-neutral-600">Key: <span className="font-semibold">{regenerateTarget?.name}</span></p>
              <Alert variant="default" className="bg-neutral-50 border-neutral-200 text-neutral-700">
                <AlertDescription>Clients using this key must update to the new value immediately.</AlertDescription>
              </Alert>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setRegenerateTarget(null)}>Cancel</Button>
              <Button id="api-key-rotate-confirm" className="bg-neutral-900 text-white" onClick={handleRegenerate}>
                Rotate key
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <Dialog open={!!revokeTarget} onOpenChange={(open) => !open && setRevokeTarget(null)}>
          <DialogContent id="api-key-revoke-dialog" className="sm:max-w-md" aria-describedby="api-key-revoke-description">
            <DialogHeader>
              <DialogTitle>Revoke API Key</DialogTitle>
              <DialogDescription id="api-key-revoke-description">
                Revoking removes access immediately. This cannot be undone.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-3">
              <p className="text-sm">Key: <span className="font-semibold">{revokeTarget?.name}</span></p>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setRevokeTarget(null)}>Cancel</Button>
              <Button id="api-key-revoke-confirm" className="bg-rose-600 text-white" onClick={handleRevoke}>
                Revoke key
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <Dialog open={isRevealOpen} onOpenChange={(open) => setRevealOpen(open)}>
          <DialogContent id="api-key-reveal-dialog" className="sm:max-w-lg" aria-describedby="api-key-reveal-description">
            <DialogHeader>
              <DialogTitle>Copy your API key</DialogTitle>
              <DialogDescription id="api-key-reveal-description">
                Treat this key like a password. Store it securely — you will not be able to retrieve it later.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div className="space-y-1">
                <Label>Key</Label>
                <Textarea
                  id="api-key-reveal-value"
                  value={tokenPayload?.value ?? ""}
                  readOnly
                  className="font-mono text-sm h-24"
                />
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold">{tokenPayload?.apiKey.name}</p>
                  <p className="text-xs text-neutral-500">Status: {tokenPayload?.context === "created" ? "Created" : "Rotated"}</p>
                </div>
                {tokenPayload?.value && <CopyButton value={tokenPayload.value} label="Copy key" />}
              </div>
            </div>
            <DialogFooter>
              <Button id="api-key-reveal-done" onClick={() => setRevealOpen(false)} className="bg-neutral-900 text-white">Done</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </Layout>
  );
}
