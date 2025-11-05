import { useRef, useState } from 'react';

import { AlertCircle, Package, Upload, X } from 'lucide-react';

import { Button } from '@/components/ui/button';

interface UploadZipFormProps {
  data: {
    archive: File | null;
  };
  setData: (key: string, value: any) => void;
  errors: any;
  onNext: () => void;
}

export const UploadZipForm = ({
  data,
  setData,
  errors,
  onNext,
}: UploadZipFormProps) => {
  const [dragActive, setDragActive] = useState(false);
  const inputReference = useRef<HTMLInputElement | null>(null);

  const isZip = (file: File) => {
    const byType = [
      'application/zip',
      'application/x-zip-compressed',
      'multipart/x-zip',
      'application/x-compressed',
      'application/octet-stream',
    ].includes(file.type);
    const byExtension = file.name.toLowerCase().endsWith('.zip');
    return byType || byExtension;
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragActive(false);
    const files = [...(e.dataTransfer.files || [])];
    const zip = files.find(isZip);
    if (zip) setData('archive', zip);
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (f && isZip(f)) setData('archive', f);
  };

  const fileState = data.archive ? 'ready' : dragActive ? 'drag' : 'idle';

  return (
    <div className="flex h-full flex-1 flex-col">
      <h2 className="mb-4 text-xl font-semibold tracking-tight">
        Upload Archive
      </h2>

      <div
        role="button"
        tabIndex={0}
        onClick={() => inputReference.current?.click()}
        onKeyDown={e =>
          (e.key === 'Enter' || e.key === ' ') &&
          inputReference.current?.click()
        }
        onDrop={handleDrop}
        onDragOver={e => {
          e.preventDefault();
          setDragActive(true);
        }}
        onDragLeave={() => setDragActive(false)}
        className={[
          'flex items-center justify-center rounded-xl border transition-colors select-none',
          'from-muted/30 to-background bg-linear-to-b',
          'ring-offset-background hover:bg-muted/40 focus-visible:ring-ring outline-none focus-visible:ring-2',
          fileState === 'idle' && 'border-border border-dashed',
          fileState === 'drag' && 'border-foreground/40 border-dashed',
          fileState === 'ready' && 'border-dashed border-emerald-500',
          'p-8',
          'flex-1',
          'min-h-[400px]',
          'text-center',
        ].join(' ')}
      >
        {!data.archive ? (
          <div className="flex flex-col items-center gap-3">
            <Upload className="text-muted-foreground h-10 w-10" />
            <div className="space-y-1">
              <p className="text-sm font-medium">Drop your .zip here</p>
              <p className="text-muted-foreground text-xs">
                or click to browse
              </p>
            </div>
            <input
              ref={inputReference}
              id="file-upload"
              type="file"
              accept=".zip"
              onChange={handleFileSelect}
              className="hidden"
            />
          </div>
        ) : (
          <div className="flex flex-col items-center gap-3">
            <Package className="h-10 w-10 text-emerald-600" />
            <div className="space-y-0.5">
              <p className="font-medium">{data.archive.name}</p>
              <p className="text-muted-foreground text-xs">
                {((data.archive.size || 0) / 1024 / 1024).toFixed(2)} MB
              </p>
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={e => {
                e.stopPropagation();
                setData('archive', null);
              }}
              className="gap-1.5"
            >
              <X className="h-3.5 w-3.5" />
              Remove
            </Button>
          </div>
        )}
      </div>

      {errors.archive && (
        <p className="text-destructive mt-3 inline-flex items-center gap-1.5 text-xs">
          <AlertCircle className="h-3.5 w-3.5" />
          {errors.archive}
        </p>
      )}

      <div className="mt-6 flex justify-end">
        <Button onClick={onNext} disabled={!data.archive}>
          Next
        </Button>
      </div>
    </div>
  );
};
