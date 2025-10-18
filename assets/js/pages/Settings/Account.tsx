import React, { useEffect, useMemo } from 'react';

import { router, useForm, usePage } from '@inertiajs/react';
import { CheckCircle2, Mail, Shield, ShieldCheck } from 'lucide-react';

import { Header } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';

type AccountProps = {
  email: string;
};

type PageProps = {
  account: AccountProps;
  email_form: {
    email: string;
    current_password?: string;
  };
  password_form: {
    password?: string;
    password_confirmation?: string;
    current_password?: string;
  };
  errors?: Record<string, string[]>;
};

const buildErrorList = (errors: Record<string, string[]>) =>
  Object.values(errors ?? {}).flat();

export default function AccountSettingsPage() {
  const { props, url } = usePage<{ props: PageProps }>();
  const account = props.account;
  const emailDefaults = props.email_form ?? { email: account.email, current_password: '' };
  const sharedErrors = props.errors ?? {};

  const emailForm = useForm({
    email: emailDefaults.email ?? account.email,
    current_password: '',
  });

  const passwordForm = useForm({
    password: '',
    password_confirmation: '',
    current_password: '',
  });

  useEffect(() => {
    emailForm.setData({
      email: emailDefaults.email ?? account.email,
      current_password: '',
    });
    emailForm.clearErrors();
  }, [emailDefaults.email, account.email]);

  useEffect(() => {
    passwordForm.setData({
      password: '',
      password_confirmation: '',
      current_password: '',
    });
    passwordForm.clearErrors();
  }, [url]);

  const emailErrorMessages = useMemo(
    () =>
      buildErrorList(
        Object.fromEntries(
          Object.entries(sharedErrors).filter(([field]) =>
            ['email', 'current_password'].includes(field),
          ),
        ),
      ),
    [sharedErrors],
  );

  const passwordErrorMessages = useMemo(
    () =>
      buildErrorList(
        Object.fromEntries(
          Object.entries(sharedErrors).filter(([field]) =>
            ['password', 'password_confirmation', 'current_password'].includes(field),
          ),
        ),
      ),
    [sharedErrors],
  );

  const handleEmailSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    emailForm.put('/settings/account/email', {
      preserveScroll: true,
      onSuccess: () => {
        emailForm.setData({
          email: account.email,
          current_password: '',
        });
        emailForm.clearErrors();
      },
    });
  };

  const handlePasswordSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    passwordForm.put('/settings/account/password', {
      preserveScroll: true,
      onSuccess: () => {
        passwordForm.reset();
      },
    });
  };

  const launchLogout = () => {
    router.delete('/users/log_out', { preserveState: false });
  };

  return (
    <Layout>
      <Header>
        <div className="flex w-full flex-col gap-6">
          <div className="flex flex-col gap-2">
            <div className="flex items-center gap-3">
              <Shield className="h-6 w-6 text-blue-500" aria-hidden />
              <span className="text-xs font-semibold uppercase tracking-[0.3em] text-blue-500">
                Account
              </span>
            </div>
            <h1 className="text-4xl font-bold leading-tight text-foreground">
              Account Settings
            </h1>
            <p className="text-muted-foreground max-w-2xl text-sm">
              Update your account settings, including your primary email address, password, and security.
            </p>
          </div>


        </div>
      </Header>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1.05fr)]">
        <div className="space-y-6">
          <Card className="border-none bg-gradient-to-br from-background via-background to-muted shadow-lg shadow-blue-500/5">
            <CardHeader className="space-y-1">
              <CardTitle className="flex items-center gap-2 text-lg font-semibold">
                <span className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-500/10">
                  <Mail className="h-5 w-5 text-blue-600" aria-hidden />
                </span>
                Primary email
              </CardTitle>
              <p className="text-muted-foreground text-sm">
                We&apos;ll send invitations, alerts, and account communications to this address.
              </p>
            </CardHeader>
            <CardContent>
              {emailErrorMessages.length > 0 && (
                <div className="mb-4 rounded-xl border border-red-300/40 bg-red-500/10 p-4 text-sm text-red-600 dark:border-red-500/40 dark:text-red-200">
                  <p className="mb-2 font-medium">We couldn&apos;t update your email.</p>
                  <ul className="space-y-1 pl-4">
                    {emailErrorMessages.map((error) => (
                      <li key={error} className="list-disc">
                        {error}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              <form
                id="account-email-form"
                className="space-y-5"
                onSubmit={handleEmailSubmit}
                noValidate
              >
                <div className="space-y-2">
                  <Label htmlFor="email">Email address</Label>
                  <Input
                    id="email"
                    type="email"
                    autoComplete="email"
                    inputMode="email"
                    value={emailForm.data.email}
                    onChange={(event) => emailForm.setData('email', event.target.value)}
                    placeholder="you@company.com"
                    className="h-11 transition-all focus-visible:ring-2 focus-visible:ring-blue-500/70"
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="email-current-password">Current password</Label>
                  <Input
                    id="email-current-password"
                    type="password"
                    autoComplete="current-password"
                    value={emailForm.data.current_password}
                    onChange={(event) => emailForm.setData('current_password', event.target.value)}
                    placeholder="••••••••••••"
                    className="h-11 transition-all focus-visible:ring-2 focus-visible:ring-blue-500/70"
                  />
                </div>

                <div className="flex flex-wrap items-center gap-3 pt-2">
                  <Button
                    type="submit"
                    disabled={emailForm.processing}
                    className="rounded-full bg-blue-600 px-6 py-2 text-sm font-semibold text-white shadow-lg shadow-blue-500/30 transition-all hover:-translate-y-0.5 hover:bg-blue-500 focus-visible:ring-blue-400"
                  >
                    {emailForm.processing ? 'Updating…' : 'Update email'}
                  </Button>
                  <span className="text-muted-foreground text-xs">
                    We&apos;ll send a confirmation link to the new address.
                  </span>
                </div>
              </form>
            </CardContent>
          </Card>

          <Card className="border-none bg-gradient-to-br from-background via-background to-muted shadow-lg shadow-purple-500/5">
            <CardHeader className="space-y-1">
              <CardTitle className="flex items-center gap-2 text-lg font-semibold">
                <span className="flex h-10 w-10 items-center justify-center rounded-full bg-purple-500/10">
                  <ShieldCheck className="h-5 w-5 text-purple-500" aria-hidden />
                </span>
                Password &amp; security
              </CardTitle>
              <p className="text-muted-foreground text-sm">
                Choose a robust password to protect team secrets and infrastructure links.
              </p>
            </CardHeader>
            <CardContent>
              {passwordErrorMessages.length > 0 && (
                <div className="mb-4 rounded-xl border border-red-300/40 bg-red-500/10 p-4 text-sm text-red-600 dark:border-red-500/40 dark:text-red-200">
                  <p className="mb-2 font-medium">We couldn&apos;t update your password.</p>
                  <ul className="space-y-1 pl-4">
                    {passwordErrorMessages.map((error) => (
                      <li key={error} className="list-disc">
                        {error}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              <form
                id="account-password-form"
                className="space-y-5"
                onSubmit={handlePasswordSubmit}
                noValidate
              >
                <div className="space-y-2">
                  <Label htmlFor="new-password">New password</Label>
                  <Input
                    id="new-password"
                    type="password"
                    autoComplete="new-password"
                    value={passwordForm.data.password ?? ''}
                    onChange={(event) => passwordForm.setData('password', event.target.value)}
                    placeholder="Create a secure password"
                    className="h-11 transition-all focus-visible:ring-2 focus-visible:ring-purple-500/70"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="confirm-password">Confirm password</Label>
                  <Input
                    id="confirm-password"
                    type="password"
                    autoComplete="new-password"
                    value={passwordForm.data.password_confirmation ?? ''}
                    onChange={(event) =>
                      passwordForm.setData('password_confirmation', event.target.value)
                    }
                    placeholder="Re-enter your password"
                    className="h-11 transition-all focus-visible:ring-2 focus-visible:ring-purple-500/70"
                  />
                </div>
                <Separator />
                <div className="space-y-2">
                  <Label htmlFor="password-current-password">Current password</Label>
                  <Input
                    id="password-current-password"
                    type="password"
                    autoComplete="current-password"
                    value={passwordForm.data.current_password ?? ''}
                    onChange={(event) =>
                      passwordForm.setData('current_password', event.target.value)
                    }
                    placeholder="••••••••••••"
                    className="h-11 transition-all focus-visible:ring-2 focus-visible:ring-purple-500/70"
                  />
                </div>

                <div className="flex flex-wrap items-center gap-3 pt-2">
                  <Button
                    type="submit"
                    disabled={passwordForm.processing}
                    className="rounded-full bg-purple-600 px-6 py-2 text-sm font-semibold text-white shadow-lg shadow-purple-500/30 transition-all hover:-translate-y-0.5 hover:bg-purple-500 focus-visible:ring-purple-400"
                  >
                    {passwordForm.processing ? 'Saving…' : 'Save new password'}
                  </Button>
                  <span className="text-muted-foreground text-xs">
                    You&apos;ll be signed out on other devices to keep things safe.
                  </span>
                </div>
              </form>
            </CardContent>
          </Card>
        </div>

        <Card className="border-none bg-gradient-to-b from-slate-950/5 via-background to-background shadow-lg shadow-emerald-500/10">
          <CardHeader className="space-y-2">
            <CardTitle className="flex items-center gap-2 text-lg font-semibold">
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-emerald-500/10">
                <Shield className="h-5 w-5 text-emerald-500" aria-hidden />
              </span>
              Security checklist
            </CardTitle>
            <p className="text-muted-foreground text-sm">
              Browsergrid makes it simple to stay protected. We recommend these best practices to
              keep your credentials pristine.
            </p>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="flex items-start gap-3 rounded-xl border border-emerald-400/30 bg-emerald-500/10 p-4 text-sm text-emerald-600 dark:text-emerald-200">
              <CheckCircle2 className="mt-0.5 h-4 w-4 flex-none" aria-hidden />
              <div>
                <p className="font-medium">Single sign-on ready</p>
                <p className="text-muted-foreground text-xs">
                  Enterprise policies? Clerk authentication keeps sign-ins unified across your
                  stack.
                </p>
              </div>
            </div>

            <ul className="space-y-4 text-sm">
              <li className="flex gap-3">
                <ShieldCheck className="mt-0.5 h-4 w-4 text-emerald-500" aria-hidden />
                <div>
                  <span className="font-medium">Rotate regularly</span>
                  <p className="text-muted-foreground">
                    Refresh your password every 90 days and revoke unused API tokens from the API
                    settings.
                  </p>
                </div>
              </li>
              <li className="flex gap-3">
                <ShieldCheck className="mt-0.5 h-4 w-4 text-emerald-500" aria-hidden />
                <div>
                  <span className="font-medium">Enable device approvals</span>
                  <p className="text-muted-foreground">
                    Approve only the workstations you trust. Suspicious logins are flagged
                    automatically.
                  </p>
                </div>
              </li>
              <li className="flex gap-3">
                <ShieldCheck className="mt-0.5 h-4 w-4 text-emerald-500" aria-hidden />
                <div>
                  <span className="font-medium">Prefer passkeys</span>
                  <p className="text-muted-foreground">
                    Passkeys deliver lightning-fast sign-ins with hardware-backed security.
                  </p>
                </div>
              </li>
            </ul>

            <Separator />

            <div className="rounded-xl border border-border bg-background/80 p-4">
              <p className="text-foreground text-sm font-semibold">Need to sign out everywhere?</p>
              <p className="text-muted-foreground text-xs">
                Log out of Browsergrid on all devices and sessions instantly.
              </p>
              <Button
                variant="outline"
                onClick={launchLogout}
                className="mt-3 w-full rounded-full border-emerald-300/60 text-emerald-600 transition-all hover:-translate-y-0.5 hover:bg-emerald-500/10"
              >
                Sign out of all sessions
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </Layout>
  );
}
