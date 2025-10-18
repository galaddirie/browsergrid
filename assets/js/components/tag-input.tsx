import { ChangeEvent, KeyboardEvent, useRef } from 'react';

import { X } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';

interface TagInputProps {
  tags: string[];
  setTags: (tags: string[]) => void;
}

// TODO: OF USER ADDS COMMA, ADD TAG
// TODO: REDESIGN TAG INPUT
export function TagInput({ tags, setTags }: TagInputProps) {
  const inputReference = useRef<HTMLInputElement>(null);

  const addTag = (tag: string) => {
    if (tag && !tags.includes(tag)) {
      setTags([...tags, tag]);
      inputReference.current!.value = '';
    }
  };

  const removeTag = (tagToRemove: string) => {
    setTags(tags.filter(tag => tag !== tagToRemove));
    inputReference.current?.focus();
  };

  const handleInputChange = (e: ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value.endsWith(' ')) {
      addTag(value.trim());
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (
      e.key === 'Backspace' &&
      !inputReference.current?.value &&
      tags.length > 0
    ) {
      e.preventDefault();
      const lastTag = tags[tags.length - 1];
      if (!lastTag) return;
      removeTag(lastTag);
      inputReference.current!.value = lastTag;
    }
  };

  return (
    <div className="w-full space-y-2">
      <div className="bg-background focus-within:ring-ring flex min-h-[2.5rem] flex-wrap items-center gap-2 rounded-md border p-2 focus-within:ring-2 focus-within:ring-offset-2">
        {tags?.map((tag, index) => (
          <Badge key={index} variant="secondary">
            {tag}
            <button
              type="button"
              onClick={() => removeTag(tag)}
              className="hover:bg-primary/20 focus-visible:ring-ring ml-1 rounded-full p-0.5 transition-colors focus-visible:ring-2 focus-visible:ring-offset-2"
              aria-label={`Remove tag ${tag}`}
            >
              <X className="h-3 w-3" />
            </button>
          </Badge>
        ))}
        <Input
          id="tag-input"
          ref={inputReference}
          type="text"
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          className="flex-grow border-none bg-transparent p-0 text-sm focus-visible:ring-0 focus-visible:ring-offset-0"
          placeholder={
            tags?.length === 0 ? 'Type and press space to add tags' : ''
          }
          aria-label="Add a new tag"
        />
      </div>
    </div>
  );
}
