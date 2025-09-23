import { useRef, useState } from "react";
import { Upload, Package, X, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";

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
  const inputRef = useRef<HTMLInputElement | null>(null);

  const isZip = (file: File) => {
    const byType = [
      "application/zip",
      "application/x-zip-compressed",
      "multipart/x-zip",
      "application/x-compressed",
      "application/octet-stream",
    ].includes(file.type);
    const byExt = file.name.toLowerCase().endsWith(".zip");
    return byType || byExt;
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragActive(false);
    const files = Array.from(e.dataTransfer.files || []);
    const zip = files.find(isZip);
    if (zip) setData("archive", zip);
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (f && isZip(f)) setData("archive", f);
  };

  const fileState = data.archive ? "ready" : dragActive ? "drag" : "idle";

  return (
    <div className="flex flex-col h-full flex-1">
      <h2 className="mb-4 text-xl font-semibold tracking-tight">Upload Archive</h2>

      <div
        role="button"
        tabIndex={0}
        onClick={() => inputRef.current?.click()}
        onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && inputRef.current?.click()}
        onDrop={handleDrop}
        onDragOver={(e) => {
          e.preventDefault();
          setDragActive(true);
        }}
        onDragLeave={() => setDragActive(false)}
        className={[
          "flex select-none items-center justify-center rounded-xl border transition-colors",
          "bg-gradient-to-b from-muted/30 to-background",
          "outline-none ring-offset-background hover:bg-muted/40 focus-visible:ring-2 focus-visible:ring-ring",
          fileState === "idle" && "border-dashed border-border",
          fileState === "drag" && "border-dashed border-foreground/40",
          fileState === "ready" && "border-dashed border-emerald-500",
          "p-8",
          "flex-1",
          "min-h-[400px]",
          "text-center",
        ].join(" ")}
      >
        {!data.archive ? (
          <div className="flex flex-col items-center gap-3">
            <Upload className="h-10 w-10 text-muted-foreground" />
            <div className="space-y-1">
              <p className="text-sm font-medium">Drop your .zip here</p>
              <p className="text-xs text-muted-foreground">or click to browse</p>
            </div>
            <input
              ref={inputRef}
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
              <p className="text-xs text-muted-foreground">
                {((data.archive.size || 0) / 1024 / 1024).toFixed(2)} MB
              </p>
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={(e) => {
                e.stopPropagation();
                setData("archive", null);
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
        <p className="mt-3 inline-flex items-center gap-1.5 text-xs text-destructive">
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

