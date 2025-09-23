
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import {
  ChevronRight,
  AlertCircle,
  Package,
  Terminal,
  Play,
  Settings,
  FolderOpen,
} from 'lucide-react';
import { Alert, AlertDescription } from '@/components/ui/alert';

interface DeploymentDetailsFormProps {
  data: {
    name: string;
    description: string;
    archive: File | null;
    root_directory: string;
    install_command: string;
    start_command: string;
    environment_variables: { key: string; value: string; }[];
    parameters: { key: string; label: string; description: string; }[];
  };
  errors: any;
  processing: boolean;
  onPrev: () => void;
  onSubmit: () => void;
}

export function DeploymentDetailsForm({
  data,
  errors,
  processing,
  onPrev,
  onSubmit,
}: DeploymentDetailsFormProps) {

  return (
    <div className="flex flex-col gap-4 justify-between h-full">
      <div className="space-y-6">
        <div>
          <h2 className="text-xl font-semibold tracking-tight">
            Review & Deploy
          </h2>
          <p className="text-sm text-muted-foreground">
            Review your deployment configuration before submitting
          </p>
        </div>

        {/* Deployment Overview */}
        <Card className="group relative overflow-hidden border border-border/50 bg-gradient-to-b from-background/10 via-background/50 to-background/80 transition-all duration-300 hover:border-border/80">
          <CardContent >
            {/* Archive info */}
            <div className="flex items-center gap-3">
              <div className="flex h-16 w-16 items-center justify-center rounded-lg border border-primary/10 bg-primary/5 p-1">
                <Package className="h-8 w-8 text-primary/50" />
              </div>
              <div>
                <h3 className="font-semibold tracking-tight">
                  {data.name || 'Untitled Deployment'}
                </h3>
                {data.description && (
                  <p className="mt-0.5 text-sm text-muted-foreground">
                    {data.description}
                  </p>
                )}
                {data.archive && (
                  <div className="mt-1 flex items-center gap-1 text-xs text-muted-foreground">
                    <FolderOpen className="h-3 w-3" />
                    <span>{data.archive.name}</span>
                    <span>({(data.archive.size / 1024 / 1024).toFixed(2)} MB)</span>
                  </div>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Runtime Configuration */}
        <div className="space-y-4">
          <div className="flex items-center gap-2">
            <Terminal className="h-4 w-4" />
            <h3 className="text-sm font-medium">Runtime Configuration</h3>
          </div>
          <div className="rounded-lg border bg-muted/5 p-4 space-y-3">
            <div className="grid grid-cols-1 gap-3 text-sm">
              <div className="flex items-center justify-between">
                <Label className="text-xs font-semibold text-muted-foreground">
                  Root Directory:
                </Label>
                <span className="font-mono">
                  {data.root_directory || './'}
                </span>
              </div>
              {data.install_command && (
                <div className="flex items-center justify-between">
                  <Label className="text-xs font-semibold text-muted-foreground">
                    Install Command:
                  </Label>
                  <span className="font-mono truncate max-w-xs">
                    {data.install_command}
                  </span>
                </div>
              )}
              <div className="flex items-center justify-between">
                <Label className="text-xs font-semibold text-muted-foreground">
                  Start Command:
                </Label>
                <span className="font-mono truncate max-w-xs flex items-center gap-1">
                  <Play className="h-3 w-3" />
                  {data.start_command}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Environment Variables */}
        {data.environment_variables && data.environment_variables.length > 0 && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-medium">Environment Variables</h3>
              <Badge variant="outline" className="font-mono text-xs">
                {data.environment_variables.filter((env: any) => env.key).length} variables
              </Badge>
            </div>
            <div className="rounded-lg border bg-muted/5 p-4">
              <div className="space-y-2">
                {data.environment_variables
                  .filter((env: any) => env.key)
                  .map((env: any, index: number) => (
                    <div key={index} className="flex items-center gap-2 text-sm">
                      <code className="font-mono text-xs bg-background px-2 py-1 rounded">
                        {env.key}
                      </code>
                      <span className="text-muted-foreground">=</span>
                      <code className="font-mono text-xs bg-background px-2 py-1 rounded flex-1 truncate">
                        {env.value || '<empty>'}
                      </code>
                    </div>
                  ))}
              </div>
            </div>
          </div>
        )}

        {/* Runtime Parameters */}
        {data.parameters && data.parameters.length > 0 && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-medium">Runtime Parameters</h3>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  Parameters that can be configured when running this deployment
                </p>
              </div>
              <Badge variant="outline" className="font-mono text-xs">
                {data.parameters.filter((param: any) => param.key).length} parameters
              </Badge>
            </div>

            <div className="space-y-2">
              {data.parameters
                .filter((param: any) => param.key)
                .map((param: any, index: number) => (
                  <div
                    key={index}
                    className="rounded-lg border bg-muted/5 p-3"
                  >
                    <div className="flex items-start justify-between">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium">
                            {param.label || param.key}
                          </span>
                        </div>
                        <div className="mt-1 flex items-center gap-2">
                          <code className="font-mono text-xs text-muted-foreground">
                            {param.key}
                          </code>
                          {param.description && (
                            <span className="text-xs text-muted-foreground">
                              · {param.description}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* No parameters message */}
        {(!data.parameters || data.parameters.filter((p: any) => p.key).length === 0) && (
          <div className="rounded-lg border border-dashed bg-muted/5 py-8 text-center text-sm text-muted-foreground">
            <Settings className="h-8 w-8 mx-auto mb-2 opacity-50" />
            No runtime parameters defined
          </div>
        )}

        {/* Error Alert */}
        {errors.submit && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>{errors.submit}</AlertDescription>
          </Alert>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center justify-between pt-6 border-t">
        <Button
          type="button"
          variant="ghost"
          onClick={onPrev}
          disabled={processing}
          className="text-muted-foreground hover:text-foreground"
        >
          Back to edit
        </Button>
        <Button
          onClick={onSubmit}
          disabled={processing}
          className="min-w-[140px]"
        >
          {processing ? (
            <>
              <div className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-background/50 border-t-transparent" />
              Deploying...
            </>
          ) : (
            <>
              Deploy
              <ChevronRight className="ml-1 h-4 w-4" />
            </>
          )}
        </Button>
      </div>
    </div>
  );
}