'use client';
import React, { useState, useRef, useEffect } from 'react';
import { Check, ChevronDown } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { cn } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';

export interface StatusOption {
  value: string;
  label: string;
  color: string;
}

interface StatusMultiSelectDropdownProps {
  options: StatusOption[];
  selectedOptions: string[];
  onChange: (selected: string[]) => void;
}

export const StatusMultiSelect: React.FC<StatusMultiSelectDropdownProps> = ({
  options,
  selectedOptions,
  onChange,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const [dropdownWidth, setDropdownWidth] = useState(0);

  useEffect(() => {
    if (triggerRef.current) {
      setDropdownWidth(triggerRef.current.offsetWidth);
    }
  }, []);

  const handleOptionToggle = (value: string) => {
    const updatedSelection = selectedOptions.includes(value)
      ? selectedOptions.filter(item => item !== value)
      : [...selectedOptions, value];
    onChange(updatedSelection);
  };

  return (
    <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
      <DropdownMenuTrigger asChild>
        <Button
          ref={triggerRef}
          variant="outline"
          className="w-full justify-between"
        >
          <span className="flex items-center space-x-1">
            {selectedOptions.map((value, index) => {
              const option = options.find(opt => opt.value === value);
              return (
                <span
                  key={value}
                  className={cn(
                    'h-2 w-2 rounded-full border border-background',
                    option?.color,
                  )}
                  style={{
                    marginLeft: index > 0 ? '-2px' : '0',
                  }}
                />
              );
            })}
            <span className="ml-2">
              Status
              <Badge
                variant="secondary"
                className="ml-2 text-xs text-muted-foreground"
              >
                {selectedOptions.length}/{options.length}
              </Badge>
            </span>
          </span>
          <ChevronDown className="h-4 w-4 opacity-50" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent style={{ width: `${dropdownWidth}px` }}>
        <div className="max-h-[300px] overflow-auto">
          {options.map(option => (
            <div
              key={option.value}
              className="flex cursor-pointer items-center justify-between px-2 py-1.5 hover:bg-gray-100"
              onClick={() => handleOptionToggle(option.value)}
            >
              <div className="flex items-center space-x-2 text-sm">
                <span className={cn('h-2 w-2 rounded-full', option.color)} />
                <span>{option.label}</span>
              </div>
              {selectedOptions.includes(option.value) && (
                <Check className="h-4 w-4 text-blue-500" />
              )}
            </div>
          ))}
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
