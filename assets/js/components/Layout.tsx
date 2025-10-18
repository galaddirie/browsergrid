import React, { useEffect } from 'react';
import { usePage } from '@inertiajs/react';
import { toast } from 'sonner';

import { Toaster } from './ui/sonner';
import { HeaderPortal } from './HeaderPortal';

/**
 * Layout component providing consistent structure across all pages
 * 
 * Structure:
 * - Fixed white header area with HeaderPortal (top ~1/3 of viewport)
 * - Scrollable grey content area (remaining ~2/3 of viewport)
 * - Toast notifications in top-right corner
 * 
 * The header uses bg-background (white) with a bottom border
 * The content area uses bg-muted/50 (light grey) and handles scrolling
 */
export default function Layout({ children }: { children: React.ReactNode }) {
    const { props } = usePage();
    const flash = (props.flash as Record<string, string>) || {};

    // Handle flash messages with Sonner toasts
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
        <div className="bg-muted/50 flex flex-grow flex-col min-h-[calc(100vh-59px)]">
            <div className="flex w-full flex-grow flex-col">
                <div className="relative flex h-full w-full flex-col items-center justify-center">
                    <div className="flex h-full w-full flex-col items-stretch justify-start">

                        {/* Header - White background with portal content */}
                        <div className="bg-background border-muted border-b pt-[100px]">
                            <header className="mx-auto max-w-7xl w-full min-h-[150px] flex flex-col items-start justify-between px-8">
                                <HeaderPortal />
                            </header>
                        </div>

                        {/* Toast Notifications - Top right corner */}
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

                        {/* Main content - Grey background, scrollable */}
                        <div className="py-6">
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