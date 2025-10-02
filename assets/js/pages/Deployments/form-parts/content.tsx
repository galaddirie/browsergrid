import React, { useEffect,useState } from 'react';

import { Play,Plus, Upload, X } from 'lucide-react';

import { TagInput } from '@/components/tag-input';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';

interface ConfigureDeploymentFormProps {
  data: {
    name: string;
    description: string;
    image: string | null;
    blurb: string;
    tags: string[];
    is_public: boolean;
    root_directory: string;
    install_command: string;
    start_command: string;
    environment_variables: { key: string; value: string; }[];
    parameters: { key: string; label: string; description: string; }[];
  };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  setData: (field: string, value: any) => void;
  errors: any;
  onNext: () => void;
  onPrev: () => void;
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
  return `linear-gradient(135deg, ${color1}, ${color2})`;
};

export const ConfigureDeploymentForm = ({
  data,
  setData,
  errors,
  onNext,
  onPrev,
}: ConfigureDeploymentFormProps) => {
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  useEffect(() => {
    if (data.image) {
      setPreviewImage(data.image);
    }
  }, [data.image]);

  const handleImageUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        const result = reader.result as string;
        setPreviewImage(result);
        setData('image', result);
      };
      reader.readAsDataURL(file);
    }
  };

  const clearImage = () => {
    setData('image', null);
    setPreviewImage(null);
  };

  const addEnvironmentVariable = () => {
    setData('environment_variables', [...data.environment_variables, { key: '', value: '' }]);
  };

  const removeEnvironmentVariable = (index: number) => {
    const updated = data.environment_variables.filter((_: any, index_: number) => index_ !== index);
    setData('environment_variables', updated);
  };

  const updateEnvironmentVariable = (index: number, field: keyof typeof data.environment_variables[0], value: string) => {
    const updated = [...data.environment_variables];
    updated[index][field] = value;
    setData('environment_variables', updated);
  };

  const addParameter = () => {
    setData('parameters', [...data.parameters, { key: '', label: '', description: '' }]);
  };

  const removeParameter = (index: number) => {
    const updated = data.parameters.filter((_: any, index_: number) => index_ !== index);
    setData('parameters', updated);
  };

  const updateParameter = (index: number, field: keyof typeof data.parameters[0], value: string) => {
    const updated = [...data.parameters];
    updated[index][field] = value;
    setData('parameters', updated);
  };

  return (
    <div className="flex flex-col gap-4 justify-between h-full">
      <div className="space-y-6">
        <div>
          <h2 className="text-xl font-semibold flex items-center gap-2">
            Configure Deployment
          </h2>
          <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
            Set up your deployment profile and runtime configuration
          </p>
        </div>

        <div className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="image" className="mb-2 block text-sm font-medium">
              Deployment Icon
            </Label>
            <div className="flex items-center space-x-4">
              <div className="flex h-16 w-16 items-center justify-center rounded-lg border border-primary/10 bg-primary/5 p-1">
                {previewImage ? (
                  <img
                    src={previewImage}
                    alt="Deployment Icon"
                    className="h-full w-full rounded-lg object-cover"
                  />
                ) : (
                  <div 
                    className="h-full w-full rounded-lg flex items-center justify-center text-white font-semibold"
                    style={{ background: generateGradient(data.name || 'Deployment') }}
                  >
                   
                  </div>
                )}
              </div>
              <div className="flex gap-2">
                <Input
                  id="image"
                  type="file"
                  accept="image/*"
                  onChange={handleImageUpload}
                  className="hidden"
                />
                <Label
                  htmlFor="image"
                  className="inline-flex h-9 flex-shrink-0 cursor-pointer items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium ring-offset-background transition-colors hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"
                >
                  <Upload className="mr-2 h-4 w-4" />
                  Upload Image
                </Label>
                {previewImage && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={clearImage}
                  >
                    <X className="mr-2 h-4 w-4" />
                    Clear
                  </Button>
                )}
              </div>
            </div>
            {errors.image && (
              <p className="text-sm text-red-500">{errors.image}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="name">
              Deployment Name <span className="text-red-500">*</span>
            </Label>
            <Input
              id="name"
              value={data.name}
              onChange={(e) => setData('name', e.target.value)}
              placeholder="Enter deployment name"
              className="w-full"
            />
            {errors.name && (
              <p className="text-sm text-red-500">{errors.name}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="blurb" className="text-sm font-medium">
              Blurb
            </Label>
            <Textarea
              id="blurb"
              value={data.blurb}
              onChange={(e) => setData('blurb', e.target.value)}
              className="min-h-[80px] w-full"
              placeholder="A short description of your deployment"
            />
            {errors.blurb && (
              <p className="text-sm text-red-500">{errors.blurb}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="description" className="text-sm font-medium">
              Description{' '}
              <span className="text-xs text-muted-foreground">(Markdown)</span>
            </Label>
            <Textarea
              id="description"
              value={data.description}
              onChange={(e) => setData('description', e.target.value)}
              className="min-h-[120px] w-full"
              placeholder="A detailed description of your deployment, how to use it, and its capabilities"
            />
            {errors.description && (
              <p className="text-sm text-red-500">{errors.description}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="tags" className="text-sm font-medium">
              Tags
            </Label>
            <TagInput
              tags={data.tags || []}
              setTags={(newTags) => setData('tags', newTags)}
            />
            {errors.tags && (
              <p className="text-sm text-red-500">{errors.tags}</p>
            )}
          </div>

        </div>

        {/* Runtime Configuration */}
        <div className="space-y-4">
          <div className="flex items-center gap-2">
            <h3 className="text-lg font-medium">Runtime Configuration</h3>
          </div>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="root_directory">Root Directory</Label>
              <Input
                id="root_directory"
                value={data.root_directory}
                onChange={(e) => setData('root_directory', e.target.value)}
                placeholder="./"
                className="w-full font-mono text-sm"
              />
              <p className="text-xs text-gray-500">
                The directory to run commands from within your archive
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="install_command">Install Command</Label>
              <Input
                id="install_command"
                value={data.install_command}
                onChange={(e) => setData('install_command', e.target.value)}
                placeholder="npm install"
                className="w-full font-mono text-sm"
              />
              <p className="text-xs text-gray-500">
                Command to install dependencies (optional)
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="start_command">
                Start Command <span className="text-red-500">*</span>
              </Label>
              <div className="relative">
                <Play className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <Input
                  id="start_command"
                  value={data.start_command}
                  onChange={(e) => setData('start_command', e.target.value)}
                  placeholder="npm start"
                  className="w-full font-mono text-sm pl-10"
                />
              </div>
              {errors.start_command && (
                <p className="text-sm text-red-500">{errors.start_command}</p>
              )}
              <p className="text-xs text-gray-500">
                Command to start your application
              </p>
            </div>
          </div>
        </div>

        {/* Environment Variables */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-medium">Environment Variables</h3>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={addEnvironmentVariable}
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Variable
            </Button>
          </div>

          <div className="space-y-2">
            {data.environment_variables.map((envVariable: any, index: number) => (
              <div key={index} className="flex gap-2 items-center">
                <Input
                  placeholder="KEY"
                  value={envVariable.key}
                  onChange={(e) => updateEnvironmentVariable(index, 'key', e.target.value)}
                  className="font-mono text-sm"
                />
                <span className="text-gray-400">=</span>
                <Input
                  placeholder="value"
                  value={envVariable.value}
                  onChange={(e) => updateEnvironmentVariable(index, 'value', e.target.value)}
                  className="font-mono text-sm"
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => removeEnvironmentVariable(index)}
                  className="text-red-500 hover:text-red-700"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}
            {data.environment_variables.length === 0 && (
              <p className="text-sm text-gray-500 text-center py-4">
                No environment variables set
              </p>
            )}
          </div>
        </div>

        {/* Parameters */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-medium">Runtime Parameters</h3>
              <p className="text-xs text-gray-500">
                Define configurable parameters for your deployment
              </p>
            </div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={addParameter}
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Parameter
            </Button>
          </div>

          <div className="space-y-3">
            {data.parameters.map((parameter: any, index: number) => (
              <div key={index} className="border rounded-lg p-4 space-y-3">
                <div className="flex justify-between items-start">
                  <h4 className="font-medium text-sm">Parameter {index + 1}</h4>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => removeParameter(index)}
                    className="text-red-500 hover:text-red-700 h-6 w-6 p-0"
                  >
                    <X className="h-4 w-4" />
                  </Button>
                </div>
                <div className="grid grid-cols-1 gap-3">
                  <Input
                    placeholder="Parameter key (e.g. max_pages)"
                    value={parameter.key}
                    onChange={(e) => updateParameter(index, 'key', e.target.value)}
                    className="font-mono text-sm"
                  />
                  <Input
                    placeholder="Display label (e.g. Maximum Pages)"
                    value={parameter.label}
                    onChange={(e) => updateParameter(index, 'label', e.target.value)}
                  />
                  <Textarea
                    placeholder="Description of what this parameter controls"
                    value={parameter.description}
                    onChange={(e) => updateParameter(index, 'description', e.target.value)}
                    className="min-h-[60px]"
                  />
                </div>
              </div>
            ))}
            {data.parameters.length === 0 && (
              <p className="text-sm text-gray-500 text-center py-4">
                No parameters defined
              </p>
            )}
          </div>
        </div>

        {/* Public Deployment */}

        <div className="flex items-center justify-between rounded-lg bg-secondary/20 p-4">
            <div className="space-y-1">
              <Label htmlFor="is_public" className="text-sm font-medium">
                Public Deployment
              </Label>
              <p className="text-xs text-muted-foreground">
                Make this deployment available in the marketplace
              </p>
            </div>
            <Switch
              id="is_public"
              checked={data.is_public}
              onCheckedChange={(checked: boolean) => setData('is_public', checked)}
            />
          </div>
      </div>

      

      <div className="flex justify-between pt-6 border-t">
        <Button type="button" variant="outline" onClick={onPrev}>
          Previous
        </Button>
        <Button type="button" onClick={onNext}>
          Next
        </Button>
      </div>
    </div>
  );
};