import React, { useEffect } from 'react';

import { Link, usePage } from '@inertiajs/react';
import {
  Box,
  Globe,
  KeyRound,
  LayoutDashboard,
  LogOut,
  Settings,
  User,
} from 'lucide-react';
import { toast } from 'sonner';

import { cn } from '@/lib/utils';

import { HeaderPortal } from './HeaderPortal';
import { Toaster } from './ui/sonner';

type NavItem = {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
};

const primaryNav: NavItem[] = [
  { href: '/', label: 'Overview', icon: LayoutDashboard },
  { href: '/sessions', label: 'Browser Sessions', icon: Globe },
  { href: '/profiles', label: 'Profiles', icon: User },
  { href: '/deployments', label: 'Deployments', icon: Box },
  { href: '/settings/account', label: 'Account', icon: Settings },
  { href: '/settings/api', label: 'API Tokens', icon: KeyRound },
];

const isActive = (currentPath: string, href: string) => {
  if (href === '/') {
    return currentPath === '/';
  }

  return currentPath === href || currentPath.startsWith(`${href}/`);
};

const navClassName = (active: boolean) =>
  cn(
    'flex items-center gap-2 border-b-2 px-1 py-3 text-sm font-medium transition-all',
    active
      ? 'border-blue-600 text-blue-600 dark:border-blue-400 dark:text-blue-400'
      : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:border-gray-600 dark:hover:text-gray-300',
  );

export default function Layout({ children }: { children: React.ReactNode }) {
  const { props, url } = usePage();
  const flash = (props.flash as Record<string, string>) || {};
  const currentUser = props.current_user as Record<string, unknown> | null;
  const currentPath = url.split('?')[0];

  useEffect(() => {
    if (flash.info) {
      toast.success(flash.info);
    }
    if (flash.error) {
      toast.error(flash.error);
    }
    if (flash.warning) {
      toast.warning(flash.warning);
    }
    if (flash.notice) {
      toast.info(flash.notice);
    }
  }, [flash]);

  return (
    <div className="flex min-h-screen flex-col bg-muted/50">


      <main className="flex flex-1 flex-col">
        <div className="flex w-full flex-grow flex-col">
          <div className="relative flex h-full w-full flex-col items-center justify-center">
            <div className="flex h-full w-full flex-col items-stretch justify-start">
              <div className="bg-background border-b border-muted pt-20">
                <header className="mx-auto flex min-h-[150px] w-full max-w-7xl flex-col items-start justify-between px-8">
                  <HeaderPortal />
                </header>
              </div>

              <Toaster
                position="top-right"
                toastOptions={{
                  duration: 4000,
                  style: {
                    background: 'hsl(var(--background))',
                    border: '1px solid hsl(var(--border))',
                    color: 'hsl(var(--foreground))',
                  },
                }}
              />

              <div className="py-6">
                <div className="mx-auto w-full max-w-7xl px-8">
                  {children}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
