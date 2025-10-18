import React, { useEffect } from 'react';

import { usePage } from '@inertiajs/react';
import { toast } from 'sonner';

import { Toaster } from './ui/sonner';
import { HeaderPortal } from './HeaderPortal';

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
        <div className="bg-background flex flex-grow flex-col">
            {/* Toast notification container */}
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
            
            <div className="flex w-full flex-grow flex-col">
                <div className="relative flex h-full w-full flex-col items-center justify-center">
                    <div className="flex grow h-full w-full  flex-col items-stretch justify-start">

                        {/* Header */}
                        <div className="border-muted border-b">
                            <header className="mx-auto max-w-7xl w-full  flex flex-col items-start justify-between  px-8">
                                <div>
                                    <HeaderPortal />
                                    

                                </div>
                            </header>
                        </div>

                        {/* Main content */}
                        <div className="bg-muted/50 py-6 h-full flex-1">
                            <div className="flex-1 mx-auto max-w-7xl w-full px-8">
                                {children}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}