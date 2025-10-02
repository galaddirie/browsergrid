"use client"

import * as React from "react"

import * as AvatarPrimitive from "@radix-ui/react-avatar"

import { cn } from "@/lib/utils"

function Avatar({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Root>) {
  return (
    <AvatarPrimitive.Root
      data-slot="avatar"
      className={cn(
        "relative flex size-8 shrink-0 overflow-hidden rounded-full",
        className
      )}
      {...props}
    />
  )
}

function AvatarImage({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Image>) {
  return (
    <AvatarPrimitive.Image
      data-slot="avatar-image"
      className={cn("aspect-square size-full", className)}
      {...props}
    />
  )
}

function AvatarFallback({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Fallback>) {
  return (
    <AvatarPrimitive.Fallback
      data-slot="avatar-fallback"
      className={cn(
        "bg-muted flex size-full items-center justify-center rounded-full",
        className
      )}
      {...props}
    />
  )
}


const generateColor = (seed: string) => {
    let hash = 0;
    for (let index = 0; index < seed.length; index++) {
      hash = seed.charCodeAt(index) + ((hash << 5) - hash);
    }
    const color = Math.floor(Math.abs(Math.sin(hash) * 16777215));
    return `#${color.toString(16).padStart(6, '0')}`;
  };
  
  const generateGradient = (name: string) => {
    const color1 = generateColor(name);
    const color2 = generateColor(name.split('').reverse().join(''));
    const color3 = null;
    return color3
      ? `linear-gradient(135deg, ${color1}, ${color2}, ${color3})`
      : `linear-gradient(135deg, ${color1}, ${color2})`;
  };
  
  export const AvatarGradientFallback =  ({ className, name, showInitials, ...props }: React.ComponentProps<typeof AvatarPrimitive.Fallback> & { name: string, showInitials?: boolean }) => {
    const initials = name
      .split(' ')
      .map(part => part[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  
    const gradientStyle = {
      background: generateGradient(name),
    };
  
    return (
      <AvatarPrimitive.Fallback
        className={cn(
          'flex h-full w-full select-none items-center justify-center rounded-full font-semibold text-white',
          className,
        )}
        style={gradientStyle}
        {...props}
      >
        {showInitials && initials}
      </AvatarPrimitive.Fallback>
    );
  };
  
  AvatarGradientFallback.displayName = 'AvatarGradientFallback';
  
  export { Avatar, AvatarFallback,AvatarImage };