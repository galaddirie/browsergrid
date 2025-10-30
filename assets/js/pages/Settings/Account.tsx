import React, { useEffect } from 'react';
import { useForm, usePage } from '@inertiajs/react';

import Layout from '@/components/Layout';
import { Header } from '@/components/HeaderPortal';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';

interface AccountProps {
  email?: string;
}

interface EmailForm {
  email?: string;
  current_password?: string;
}

interface PasswordForm {
  password?: string;
  password_confirmation?: string;
  current_password?: string;
}

interface PageProps {
  account?: AccountProps;
  email_form?: EmailForm;
  password_form?: PasswordForm;
  errors?: Record<string, string | string[]>;
}

function flattenErrors(errors?: Record<string, string | string[]>) {
  if (!errors) return [];
  return Object.values(errors)
    .map(v => (Array.isArray(v) ? v : [v]))
    .flat();
}

function ErrorBox({ errors }: { errors: string[] }) {
  if (!errors?.length) return null;
  return (
    <div className="border-destructive/30 bg-destructive/10 text-destructive rounded-md border p-3 text-sm">
      <ul className="list-disc space-y-1 pl-4">
        {errors.map(e => (
          <li key={e}>{e}</li>
        ))}
      </ul>
    </div>
  );
}

export default function AccountSettingsPage() {
  const { props, url } = usePage<{ props: PageProps }>();
  const account: AccountProps = props.account ?? {};
  const email_form: EmailForm = props.email_form ?? {};
  const sharedErrors = props.errors;

  const emailForm = useForm({
    email: email_form.email ?? account.email ?? '',
    current_password: '',
  });

  const passwordForm = useForm({
    password: '',
    password_confirmation: '',
    current_password: '',
  });

  useEffect(() => {
    emailForm.setData({
      email: email_form.email ?? account.email ?? '',
      current_password: '',
    });
    emailForm.clearErrors();
  }, [email_form.email, account.email]);

  useEffect(() => {
    passwordForm.reset();
    passwordForm.clearErrors();
  }, [url]);

  const emailErrors = flattenErrors(
    sharedErrors
      ? Object.fromEntries(
          Object.entries(sharedErrors).filter(([k]) =>
            ['email', 'current_password'].includes(k),
          ),
        )
      : undefined,
  );

  const passwordErrors = flattenErrors(
    sharedErrors
      ? Object.fromEntries(
          Object.entries(sharedErrors).filter(([k]) =>
            ['password', 'password_confirmation', 'current_password'].includes(
              k,
            ),
          ),
        )
      : undefined,
  );

  function submitEmail(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    emailForm.put('/settings/account/email', {
      preserveScroll: true,
      onSuccess: () => {
        emailForm.setData({ email: account.email ?? '', current_password: '' });
        emailForm.clearErrors();
      },
    });
  }

  function submitPassword(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    passwordForm.put('/settings/account/password', {
      preserveScroll: true,
      onSuccess: () => passwordForm.reset(),
    });
  }



  return (
    <Layout>
      <Header>
        <div className="flex w-full flex-col gap-6">
          <div className="flex flex-col gap-2">
            <h1 className="text-foreground text-4xl leading-tight font-bold">
              Account Settings
            </h1>
            <p className="text-muted-foreground max-w-2xl text-sm">
              Update your account settings, including your primary email
              address, password, and security.
            </p>
          </div>
        </div>
      </Header>

      <div className="mx-auto max-w-2xl space-y-6">
        {/* Email */}
        <Card className="bg-background border">
          <CardHeader className="space-y-1">
            <CardTitle className="text-base font-medium">
              Primary email
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <ErrorBox errors={emailErrors} />
            <form onSubmit={submitEmail} noValidate className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  inputMode="email"
                  value={emailForm.data.email}
                  onChange={e => emailForm.setData('email', e.target.value)}
                  placeholder="you@company.com"
                  className="h-10"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="email-current-password">Current password</Label>
                <Input
                  id="email-current-password"
                  type="password"
                  autoComplete="current-password"
                  value={emailForm.data.current_password}
                  onChange={e =>
                    emailForm.setData('current_password', e.target.value)
                  }
                  placeholder="••••••••"
                  className="h-10"
                />
              </div>
              <div className="flex items-center gap-3 pt-1">
                <Button type="submit" size="sm" disabled={emailForm.processing}>
                  {emailForm.processing ? 'Updating…' : 'Update email'}
                </Button>
                <span className="text-muted-foreground text-xs">
                  We’ll send a confirmation link.
                </span>
              </div>
            </form>
          </CardContent>
        </Card>

        {/* Password */}
        <Card className="bg-background border">
          <CardHeader className="space-y-1">
            <CardTitle className="text-base font-medium">Password</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <ErrorBox errors={passwordErrors} />
            <form onSubmit={submitPassword} noValidate className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="new-password">New password</Label>
                <Input
                  id="new-password"
                  type="password"
                  autoComplete="new-password"
                  value={passwordForm.data.password ?? ''}
                  onChange={e =>
                    passwordForm.setData('password', e.target.value)
                  }
                  placeholder="Create a secure password"
                  className="h-10"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirm-password">Confirm password</Label>
                <Input
                  id="confirm-password"
                  type="password"
                  autoComplete="new-password"
                  value={passwordForm.data.password_confirmation ?? ''}
                  onChange={e =>
                    passwordForm.setData(
                      'password_confirmation',
                      e.target.value,
                    )
                  }
                  placeholder="Re-enter your password"
                  className="h-10"
                />
              </div>
              <Separator />
              <div className="space-y-2">
                <Label htmlFor="password-current-password">
                  Current password
                </Label>
                <Input
                  id="password-current-password"
                  type="password"
                  autoComplete="current-password"
                  value={passwordForm.data.current_password ?? ''}
                  onChange={e =>
                    passwordForm.setData('current_password', e.target.value)
                  }
                  placeholder="••••••••"
                  className="h-10"
                />
              </div>
              <div className="pt-1">
                <Button
                  type="submit"
                  size="sm"
                  disabled={passwordForm.processing}
                >
                  {passwordForm.processing ? 'Saving…' : 'Save password'}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>


      </div>
    </Layout>
  );
}
