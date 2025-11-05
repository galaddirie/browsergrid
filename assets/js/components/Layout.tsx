import React, { useEffect } from 'react';

import { usePage } from '@inertiajs/react';
import { toast } from 'sonner';

import { HeaderPortal } from './HeaderPortal';
import { Toaster } from './ui/sonner';

export default function Layout({ children }: { children: React.ReactNode }) {
  const { props } = usePage();
  const flash = (props.flash as Record<string, string>) || {};

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
    <div className="bg-muted/50 flex min-h-screen flex-col">
      <main className="flex flex-1 flex-col">
        <div className="flex w-full grow flex-col">
          <div className="relative flex h-full w-full flex-col items-center justify-center">
            <div className="flex h-full w-full flex-col items-stretch justify-start">
              <div className="bg-background border-muted border-b pt-20">
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
                <div className="mx-auto w-full max-w-7xl px-8">{children}</div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
