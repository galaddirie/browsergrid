import React, { useState } from 'react';

import {
  AlignJustify,
  ArrowUp10,
  Box,
  Calendar,
  CalendarClock,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  Clock,
  Equal,
  EqualNot,
  Filter,
  FilterX,
  List,
  Plus,
  Settings,
  ToggleLeft,
  Trash2,
  Type,
  Upload,
  X,
} from 'lucide-react';
import { v4 as uuid } from 'uuid';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';

const FIELD_TYPES: {
  type: "string" | "number" | "boolean" | "date" | "time" | "datetime" | "file" | "select" | "array" | "object";
  icon: any;
  label: string;
  description: string;
}[] = [
  {
    type: 'string',
    icon: Type,
    label: 'Text Field',
    description: 'Single line text input',
  },
  {
    type: 'number',
    icon: ArrowUp10,
    label: 'Number',
    description: 'Numeric input field',
  },
  {
    type: 'boolean',
    icon: ToggleLeft,
    label: 'Toggle',
    description: 'True/false switch',
  },
  { type: 'date', icon: Calendar, label: 'Date', description: 'Date picker' },
  { type: 'time', icon: Clock, label: 'Time', description: 'Time picker' },
  {
    type: 'datetime',
    icon: CalendarClock,
    label: 'Date & Time',
    description: 'Combined date and time',
  },
  {
    type: 'file',
    icon: Upload,
    label: 'File Upload',
    description: 'File upload field',
  },
  {
    type: 'select',
    icon: List,
    label: 'Dropdown',
    description: 'Selection from options',
  },
  {
    type: 'array',
    icon: AlignJustify,
    label: 'Array',
    description: 'List of items',
  },
  {
    type: 'object',
    icon: Box,
    label: 'Object',
    description: 'Nested form fields',
  },
];

const groupedFields = {
  basic: FIELD_TYPES.filter(f =>
    ['string', 'number', 'boolean'].includes(f.type),
  ),
  datetime: FIELD_TYPES.filter(f =>
    ['date', 'time', 'datetime'].includes(f.type),
  ),
  complex: FIELD_TYPES.filter(f =>
    ['file', 'select', 'array', 'object'].includes(f.type),
  ),
};

interface FieldType {
  customId: string;
  name: string;
  label: string;
  type: "string" | "number" | "boolean" | "date" | "time" | "datetime" | "file" | "select" | "array" | "object";
  is_required: boolean;
  description: string;
  default: string;
  placeholder: string;
  disabled: boolean;
  hidden: boolean;
  readOnly: boolean;
  options: any;
  conditions: {
    field: string;
    operator: string;
    value: string;
  }[];
}

interface DeploymentParametersFormProps {
  data: {
    name: string;
    package_parameters: {
      title: string;
      description: string;
      fields: FieldType[];
    };
  };
  setData: (field: string, value: any) => void;
  errors: any;
  onNext: () => void;
  onPrev: () => void;
}

export function DeploymentParametersForm({
  data,
  setData,
  errors,
  onNext,
  onPrev,
}: DeploymentParametersFormProps) {
  const [selectedFieldId, setSelectedFieldId] = useState<string | null>(null);
  const [tabIndex, setTabIndex] = useState<'inputs' | 'properties'>('inputs');

  const packageData = data.package_parameters;
    
  if (!packageData.title && data.name) {
    packageData.title = `${data.name}'s Inputs`;
  }

  const fields = packageData.fields || [];
  const selectedIndex = fields.findIndex(f => f.customId === selectedFieldId);

  const updatePackageData = (updates: any) => {
    const newPackageData = {
      ...packageData,
      ...updates
    };
    setData('package_parameters', newPackageData);
  };

  const handleAddField = (type: "string" | "number" | "boolean" | "date" | "time" | "datetime" | "file" | "select" | "array" | "object") => {
    const customId = uuid();
    const newField: FieldType = {
      customId,
      name: '',
      label: '',
      type,
      is_required: true,
      description: '',
      default: '',
      placeholder: '',
      disabled: false,
      hidden: false,
      readOnly: false,
      options: {},
      conditions: [],
    };

    updatePackageData({
      fields: [...fields, newField]
    });

    setSelectedFieldId(customId);
    setTabIndex('properties');
  };

  const removeField = (index: number) => {
    const fieldId = fields[index]?.customId;
    const updatedFields = fields.filter((_, index_) => index_ !== index);
    
    updatePackageData({
      fields: updatedFields
    });

    if (fieldId === selectedFieldId) {
      let newSelectedFieldId: string | null = null;
      if (index < updatedFields.length) {
        newSelectedFieldId = updatedFields[index]?.customId;
      } else if (index > 0) {
        newSelectedFieldId = updatedFields[index - 1]?.customId;
      }
      
      if (newSelectedFieldId) {
        setSelectedFieldId(newSelectedFieldId);
        setTabIndex('properties');
      } else {
        setSelectedFieldId(null);
        setTabIndex('inputs');
      }
    }
  };

  const swapFields = (indexA: number, indexB: number) => {
    if (indexA < 0 || indexB < 0 || indexA >= fields.length || indexB >= fields.length) return;
    
    const updatedFields = [...fields];
    [updatedFields[indexA], updatedFields[indexB]] = [updatedFields[indexB], updatedFields[indexA]];
    
    updatePackageData({
      fields: updatedFields
    });
  };

  const updateField = (index: number, updates: Partial<FieldType>) => {
    const updatedFields = [...fields];
    updatedFields[index] = { ...updatedFields[index], ...updates };
    
    updatePackageData({
      fields: updatedFields
    });
  };

  React.useEffect(() => {
    if (fields.length === 0) {
      setTabIndex('inputs');
      setSelectedFieldId(null);
    }
  }, [fields.length]);

  return (
    <div className="flex flex-col gap-4 justify-between h-full">
      <div>
        {/* Title & Description */}
        <div className="mb-12">
          <div className="flex items-start justify-between">
            <div>
              <h2 className="text-xl font-bold tracking-tight">Runtime Parameters</h2>
              <p className="mt-3 max-w-2xl text-sm text-muted-foreground">
                Set up the dynamic user inputs your deployment needs to run.
                <br />
                Each time you launch it — via the dashboard or API — you'll
                provide these values to initialize the deployment.
                <br />
                <br />
                <span className="font-semibold">
                  Not sure what to add? Skip for now and come back later.
                </span>
              </p>
            </div>
            <Button type="button" onClick={onNext}>
              Skip
            </Button>
          </div>
          <div className="mt-6 flex items-center gap-2 rounded-lg border border-blue-100 bg-blue-50 p-4 dark:border-blue-800 dark:bg-blue-900/20">
            <div className="h-10 w-1 rounded-full bg-blue-500/50" />
            <p className="text-sm text-blue-700 dark:text-blue-300 lg:text-xs">
              <strong>Tip:</strong> Consider adding inputs like URLs, keywords, or
              custom parameters.
              <br />
              Your deployment will use these inputs to run.
            </p>
          </div>
        </div>

        <div className="flex gap-8">
          {/* Left side: Fields preview & overall form */}
          <div className="flex-1 space-y-8">
            {/* Basic form title & description */}
            <div className="space-y-6">
              <div>
                <Label className="text-sm font-medium">Form Title</Label>
                <Input
                  className="mt-2"
                  value={packageData.title}
                  placeholder="Form title"
                  onChange={(e) => updatePackageData({ title: e.target.value })}
                />
                {errors?.['package_parameters.title'] && (
                  <p className="text-sm text-destructive">
                    {errors['package_parameters.title']}
                  </p>
                )}
              </div>
              <div>
                <Label className="text-sm font-medium">Description</Label>
                <Textarea
                  className="mt-2"
                  placeholder="Explain how these parameters will be used"
                  value={packageData.description}
                  onChange={(e) => updatePackageData({ description: e.target.value })}
                />
              </div>
            </div>

            {/* Fields list */}
            <div>
              <div className="mb-4 flex items-center justify-between">
                <h3 className="text-sm font-medium">Form Fields</h3>
                <Button
                  className="h-full py-1 text-xs"
                  type="button"
                  onClick={() => setTabIndex('inputs')}
                  disabled={tabIndex === 'inputs'}
                  variant="outline"
                >
                  <Plus size={16} className="mr-2" />
                  Add Field
                </Button>
              </div>
              
              {fields.length === 0 ? (
                <div className="rounded-lg border-2 border-dashed p-8 text-center">
                  <Settings className="h-8 w-8 mx-auto mb-2 opacity-50" />
                  <p className="text-xs text-muted-foreground">
                    No fields added yet
                  </p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    Start by adding a field from the right panel
                  </p>
                </div>
              ) : (
                <div className="space-y-1.5">
                  {fields.map((field, index) => {
                    const isSelected = field.customId === selectedFieldId;
                    const fieldErrors = errors?.[`package_parameters.fields.${index}`];
                    const hasError = !!fieldErrors && Object.keys(fieldErrors).length > 0;
                    const fieldIcon = FIELD_TYPES.find(t => t.type === field.type)?.icon || Type;

                    return (
                      <div
                        key={field.customId}
                        onClick={() => {
                          setSelectedFieldId(field.customId);
                          setTabIndex('properties');
                        }}
                        className={cn(
                          'group relative rounded-lg border px-4 py-3 transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-800/50',
                          'cursor-pointer',
                          {
                            'border-blue-500 bg-blue-50/30 ring-1 ring-blue-500 dark:bg-blue-900/10':
                              isSelected && !hasError,
                            'border-red-500 bg-red-50/30 ring-1 ring-red-500 dark:bg-red-900/10':
                              hasError,
                            border: !isSelected && !hasError,
                          },
                        )}
                      >
                        <div className="flex items-center justify-between gap-4">
                          <div className="flex min-w-0 items-center gap-3">
                            {React.createElement(fieldIcon, {
                              size: 16,
                              className: cn(
                                'shrink-0 text-slate-500 dark:text-slate-400',
                                { 'text-blue-500': isSelected },
                              ),
                            })}
                            <div className="min-w-0">
                              <p
                                className={cn(
                                  'truncate text-sm font-medium text-slate-900 dark:text-slate-100',
                                  {
                                    'text-blue-600 dark:text-blue-400': isSelected,
                                  },
                                )}
                              >
                                {field.label || `Untitled ${field.type} field`}
                              </p>
                              <p className="truncate text-xs text-slate-500 dark:text-slate-400">
                                {field.name || 'No field name set'}
                              </p>
                            </div>
                          </div>

                          <div className="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                            <Badge
                              variant="secondary"
                              className="bg-slate-100 px-2 py-0.5 text-xs text-slate-600 dark:bg-slate-800 dark:text-slate-300"
                            >
                              {field.type}
                            </Badge>

                            <div className="mx-2 h-4 w-px bg-slate-200 dark:bg-slate-700" />

                            <div className="flex items-center">
                              <Button
                                variant="ghost"
                                type="button"
                                size="sm"
                                className="h-7 w-7 p-0 hover:bg-slate-100 dark:hover:bg-slate-800"
                                onClick={e => {
                                  e.stopPropagation();
                                  if (index > 0) swapFields(index, index - 1);
                                }}
                              >
                                <ChevronUp size={14} />
                              </Button>
                              <Button
                                variant="ghost"
                                type="button"
                                size="sm"
                                className="h-7 w-7 p-0 hover:bg-slate-100 dark:hover:bg-slate-800"
                                onClick={e => {
                                  e.stopPropagation();
                                  if (index < fields.length - 1)
                                    swapFields(index, index + 1);
                                }}
                              >
                                <ChevronDown size={14} />
                              </Button>
                              <Button
                                variant="ghost"
                                type="button"
                                size="sm"
                                className="h-7 w-7 p-0 text-red-400 hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-900/20"
                                onClick={e => {
                                  e.stopPropagation();
                                  removeField(index);
                                }}
                              >
                                <Trash2 size={14} />
                              </Button>
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          {/* Right Panel: Tabs */}
          <div className="w-96">
            <Card className="p-4">
              <Tabs
                value={tabIndex}
                onValueChange={(v: 'inputs' | 'properties') => setTabIndex(v)}
              >
                <TabsList className="mb-6 grid h-full w-full grid-cols-1 md:grid-cols-2">
                  <TabsTrigger value="inputs">Add Fields</TabsTrigger>
                  <TabsTrigger value="properties" disabled={selectedIndex === -1}>
                    Properties
                  </TabsTrigger>
                </TabsList>

                {/* Tab 1: Add fields */}
                <TabsContent value="inputs" className="space-y-6">
                  <div className="space-y-1">
                    <h3 className="text-lg font-semibold tracking-tight">
                      Add Field
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Choose a field type to add to your form
                    </p>
                  </div>

                  <div className="space-y-6">
                    {Object.entries(groupedFields).map(([category, fields]) => (
                      <div key={category} className="space-y-3">
                        <h4 className="text-sm font-medium capitalize text-muted-foreground">
                          {category} Fields
                        </h4>
                        <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
                          {fields.map(
                            ({ type, icon: Icon, label, description }) => (
                              <div
                                key={type}
                                onClick={() => handleAddField(type)}
                                className="group relative cursor-pointer rounded-lg border-2 border-gray-100 p-3 transition-all duration-100 hover:border-blue-500/50 hover:bg-blue-50/50 hover:shadow-lg hover:shadow-blue-100/50 dark:border-gray-800 dark:hover:border-blue-500/50 dark:hover:bg-blue-900/20 dark:hover:shadow-blue-900/40"
                                aria-label={`Add ${label} field`}
                                role="button"
                                tabIndex={0}
                              >
                                <div className="flex items-center gap-4">
                                  <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-gradient-to-br from-blue-50 to-blue-100 group-hover:from-blue-100 group-hover:to-blue-200 dark:from-blue-900/40 dark:to-blue-800/40 dark:group-hover:from-blue-800/60 dark:group-hover:to-blue-700/60">
                                    <Icon className="h-6 w-6 text-blue-600 group-hover:text-blue-700 dark:text-blue-400 dark:group-hover:text-blue-300" />
                                  </div>
                                  <div className="min-w-0 flex-1">
                                    <p className="text-sm font-medium text-gray-900 transition-colors duration-200 group-hover:text-blue-700 dark:text-gray-100 dark:group-hover:text-blue-300">
                                      {label}
                                    </p>
                                    <p className="mt-0.5 truncate text-xs text-gray-500 dark:text-gray-400">
                                      {description}
                                    </p>
                                  </div>
                                </div>
                                <div className="pointer-events-none absolute inset-0 rounded-lg border-2 border-transparent transition-colors duration-200 group-hover:border-blue-500/20 dark:group-hover:border-blue-500/20" />
                              </div>
                            ),
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </TabsContent>

                {/* Tab 2: Field Properties */}
                <TabsContent value="properties">
                  {selectedIndex !== -1 && fields[selectedIndex] && (
                    <FieldPropertiesPanel
                      key={selectedFieldId}
                      field={fields[selectedIndex]}
                      fieldIndex={selectedIndex}
                      errors={errors}
                      onUpdateField={(updates) => updateField(selectedIndex, updates)}
                    />
                  )}
                </TabsContent>
              </Tabs>
            </Card>
          </div>
        </div>
      </div>

      {/* Navigation buttons */}
      <div className="flex justify-between pt-6 border-t">
        <Button onClick={onPrev} variant="outline" type="button">
          Previous
        </Button>
        <Button onClick={onNext} type="button">
          Next
        </Button>
      </div>
    </div>
  );
}

interface FieldPropertiesPanelProps {
  field: FieldType;
  fieldIndex: number;
  errors: any;
  onUpdateField: (updates: Partial<FieldType>) => void;
}

function FieldPropertiesPanel({
  field,
  fieldIndex,
  errors,
  onUpdateField,
}: FieldPropertiesPanelProps) {
  const exampleLabelPlaceholder = (currentType: string) => {
    switch (currentType) {
      case 'string':
        return 'e.g. Search Keywords, Website URL, Login Username';
      case 'number':
        return 'e.g. Maximum Results, Wait Time (seconds), Retry Count';
      case 'boolean':
        return 'e.g. Save Screenshots, Use Proxy, Ignore Errors';
      case 'date':
        return 'e.g. Data From Date, Schedule Start, Post After';
      case 'time':
        return 'e.g. Daily Run Time, Check Interval, Timeout Duration';
      case 'datetime':
        return 'e.g. Schedule Task At, Monitor Until, Publish Time';
      case 'file':
        return 'e.g. Input CSV, Product List, Upload Template';
      case 'select':
        return 'e.g. Browser Type, Output Format, Target Platform';
      case 'array':
        return 'e.g. Target URLs, Email Recipients, Search Terms';
      case 'object':
        return 'e.g. API Credentials, Browser Settings, Proxy Config';
      default:
        return '';
    }
  };

  const exampleFieldNamePlaceholder = (currentType: string) => {
    switch (currentType) {
      case 'string':
        return 'e.g. search_query, target_url, login_email';
      case 'number':
        return 'e.g. max_results, wait_seconds, retry_count';
      case 'boolean':
        return 'e.g. save_screenshots, is_recursive, ignore_errors';
      case 'date':
        return 'e.g. start_from, schedule_date, publish_after';
      case 'time':
        return 'e.g. run_time, check_interval, timeout_duration';
      case 'datetime':
        return 'e.g. schedule_at, monitor_until, publish_time';
      case 'file':
        return 'e.g. input_csv, product_list, template_file';
      case 'select':
        return 'e.g. browser_type, output_format, target_platform';
      case 'array':
        return 'e.g. target_urls, recipients, search_terms';
      case 'object':
        return 'e.g. json_data, credentials, config';
      default:
        return '';
    }
  };

  return (
    <div className="w-full space-y-6 animate-in fade-in-50">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h3 className="text-lg font-semibold tracking-tight">
            Field Properties
          </h3>
          <p className="text-sm text-muted-foreground">
            Configure the selected field's behavior and appearance
          </p>
        </div>
        <Badge variant="secondary" className="h-6 whitespace-nowrap">
          ID: {fieldIndex}
        </Badge>
      </div>

      <Separator />

      {/* Basic Settings */}
      <div className="space-y-6">
        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Field Key</Label>
            <Input
              className="font-mono text-sm"
              placeholder={exampleFieldNamePlaceholder(field.type)}
              value={field.name}
              onChange={(e) => onUpdateField({ name: e.target.value })}
            />
            {errors?.[`package_parameters.fields.${fieldIndex}.name`] && (
              <p className="text-sm text-destructive">
                {errors[`package_parameters.fields.${fieldIndex}.name`]}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label>Display Label</Label>
            <Input
              placeholder={exampleLabelPlaceholder(field.type)}
              value={field.label}
              onChange={(e) => onUpdateField({ label: e.target.value })}
            />
            {errors?.[`package_parameters.fields.${fieldIndex}.label`] && (
              <p className="text-sm text-destructive">
                {errors[`package_parameters.fields.${fieldIndex}.label`]}
              </p>
            )}
          </div>
        </div>

        {/* Field Settings */}
        <div className="grid gap-4">
          <div className="flex flex-wrap gap-4">
            <div className="flex items-center space-x-2">
              <Checkbox
                id={`field-${fieldIndex}-required`}
                checked={field.is_required}
                onCheckedChange={(checked) => onUpdateField({ is_required: !!checked })}
              />
              <Label htmlFor={`field-${fieldIndex}-required`} className="text-xs">
                Required
              </Label>
            </div>
            <div className="flex items-center space-x-2">
              <Checkbox
                id={`field-${fieldIndex}-hidden`}
                checked={field.hidden}
                onCheckedChange={(checked) => onUpdateField({ hidden: !!checked })}
              />
              <Label htmlFor={`field-${fieldIndex}-hidden`} className="text-xs">
                Hidden
              </Label>
            </div>
            <div className="flex items-center space-x-2">
              <Checkbox
                id={`field-${fieldIndex}-readonly`}
                checked={field.readOnly}
                onCheckedChange={(checked) => onUpdateField({ readOnly: !!checked })}
              />
              <Label htmlFor={`field-${fieldIndex}-readonly`} className="text-xs">
                Read Only
              </Label>
            </div>
          </div>
        </div>

        {/* Description */}
        <div className="space-y-2">
          <Label>Description</Label>
          <Textarea
            className="min-h-[80px] resize-y text-sm"
            placeholder="Help text or instructions for this field..."
            value={field.description}
            onChange={(e) => onUpdateField({ description: e.target.value })}
          />
        </div>
      </div>

      <Separator />

      {/* Advanced Settings */}
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            Advanced Settings
          </h4>
          <p className="text-sm text-muted-foreground">
            Configure additional field behavior
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Default Value</Label>
            <Input
              className="text-sm"
              placeholder="Optional default value"
              value={field.default}
              onChange={(e) => onUpdateField({ default: e.target.value })}
            />
          </div>
          <div className="space-y-2">
            <Label>Placeholder</Label>
            <Input
              className="text-sm"
              placeholder="Placeholder text"
              value={field.placeholder}
              onChange={(e) => onUpdateField({ placeholder: e.target.value })}
            />
          </div>
        </div>
      </div>

      <Separator />

      {/* Type-specific Options */}
      <TypeSpecificOptions
        type={field.type}
        field={field}
        onUpdateField={onUpdateField}
      />

      <Separator />

      {/* Conditional Logic */}
      <ConditionsEditor
        field={field}
        onUpdateField={onUpdateField}
      />
    </div>
  );
}

function TypeSpecificOptions({
  type,
  field,
  onUpdateField,
}: {
  type: "string" | "number" | "boolean" | "date" | "time" | "datetime" | "file" | "select" | "array" | "object";
  field: FieldType;
  onUpdateField: (updates: Partial<FieldType>) => void;
}) {
  const updateOptions = (path: string, value: any) => {
    const pathParts = path.split('.');
    const newOptions = { ...field.options };
    
    let current = newOptions;
    for (let index = 0; index < pathParts.length - 1; index++) {
      if (!current[pathParts[index]]) {
        current[pathParts[index]] = {};
      }
      current = current[pathParts[index]];
    }
    current[pathParts[pathParts.length - 1]] = value;
    
    onUpdateField({ options: newOptions });
  };

  const getOptionValue = (path: string) => {
    const pathParts = path.split('.');
    let current = field.options;
    for (const part of pathParts) {
      current = current?.[part];
      if (current === undefined) return '';
    }
    return current || '';
  };

  if (type === 'string') {
    return (
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            String Options
          </h4>
          <p className="text-xs text-muted-foreground">
            Configure string-specific validations
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Format</Label>
            <Select
              value={getOptionValue('string.format') || 'none'}
              onValueChange={(value: string) => updateOptions('string.format', value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select format" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">none</SelectItem>
                <SelectItem value="email">email</SelectItem>
                <SelectItem value="uri">uri</SelectItem>
                <SelectItem value="uuid">uuid</SelectItem>
                <SelectItem value="date">date</SelectItem>
                <SelectItem value="password">password</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label>Min Length</Label>
            <Input
              type="number"
              className="text-xs"
              value={getOptionValue('string.minLength')}
              onChange={(e) => updateOptions('string.minLength', e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Max Length</Label>
            <Input
              type="number"
              className="text-xs"
              value={getOptionValue('string.maxLength')}
              onChange={(e) => updateOptions('string.maxLength', e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Regex Pattern</Label>
            <Input
              className="font-mono text-xs"
              placeholder="^[a-zA-Z0-9]*$"
              value={getOptionValue('string.regex')}
              onChange={(e) => updateOptions('string.regex', e.target.value)}
            />
          </div>
        </div>
      </div>
    );
  }

  if (type === 'number') {
    return (
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            Number Options
          </h4>
          <p className="text-xs text-muted-foreground">
            Configure numeric constraints and behavior
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Minimum Value</Label>
            <Input
              type="number"
              className="text-xs"
              value={getOptionValue('number.minimum')}
              onChange={(e) => updateOptions('number.minimum', e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Maximum Value</Label>
            <Input
              type="number"
              className="text-xs"
              value={getOptionValue('number.maximum')}
              onChange={(e) => updateOptions('number.maximum', e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Multiple Of</Label>
            <Input
              type="number"
              className="text-xs"
              placeholder="e.g. 5 for multiples of 5"
              value={getOptionValue('number.multipleOf')}
              onChange={(e) => updateOptions('number.multipleOf', e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Step</Label>
            <Input
              type="number"
              className="text-xs"
              placeholder="Increment/decrement step"
              value={getOptionValue('number.step')}
              onChange={(e) => updateOptions('number.step', e.target.value)}
            />
          </div>
        </div>
      </div>
    );
  }

  if (type === 'select') {
    return (
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            Select Options
          </h4>
          <p className="text-xs text-muted-foreground">
            Configure dropdown choices and behavior
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Options Array</Label>
            <Textarea
              className="min-h-[100px] resize-y font-mono text-xs"
              placeholder={`[
  {"value": "us", "label": "United States"},
  {"value": "uk", "label": "United Kingdom"}
]`}
              value={getOptionValue('select.options')}
              onChange={(e) => updateOptions('select.options', e.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              JSON array of options with value and label properties
            </p>
          </div>

          <div className="space-y-4">
            <div className="flex items-center space-x-2">
              <Checkbox
                id="select-multiple"
                checked={!!getOptionValue('select.multiple')}
                onCheckedChange={(checked) => updateOptions('select.multiple', checked)}
              />
              <Label htmlFor="select-multiple" className="text-xs">
                Allow multiple selections
              </Label>
            </div>
            <div className="flex items-center space-x-2">
              <Checkbox
                id="select-other"
                checked={!!getOptionValue('select.other')}
                onCheckedChange={(checked) => updateOptions('select.other', checked)}
              />
              <Label htmlFor="select-other" className="text-xs">
                Include "Other" option with custom input
              </Label>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (type === 'file') {
    return (
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            File Upload Options
          </h4>
          <p className="text-xs text-muted-foreground">
            Configure file upload constraints
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Accepted Types/Extensions</Label>
            <Textarea
              className="min-h-[80px] resize-y font-mono text-xs"
              placeholder={`["image/png", "image/jpeg", ".pdf", ".doc"]`}
              value={getOptionValue('file.accept')}
              onChange={(e) => updateOptions('file.accept', e.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              MIME types or file extensions in JSON array format
            </p>
          </div>
          <div className="space-y-2">
            <Label>Max File Size</Label>
            <div className="flex items-center gap-2">
              <Input
                type="number"
                className="text-xs"
                value={getOptionValue('file.maxFileSize')}
                onChange={(e) => updateOptions('file.maxFileSize', e.target.value)}
              />
              <span className="text-sm text-muted-foreground">bytes</span>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            <Checkbox
              id="file-multiple"
              checked={!!getOptionValue('file.multiple')}
              onCheckedChange={(checked) => updateOptions('file.multiple', checked)}
            />
            <Label htmlFor="file-multiple" className="text-xs">
              Allow multiple files
            </Label>
          </div>
        </div>
      </div>
    );
  }

  if (type === 'array') {
    return (
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            Array Options
          </h4>
          <p className="text-sm text-muted-foreground">
            Configure array field constraints
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Minimum Items</Label>
            <Input
              type="number"
              className="text-sm"
              placeholder="e.g. 1"
              value={getOptionValue('array.minItems')}
              onChange={(e) => updateOptions('array.minItems', e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Maximum Items</Label>
            <Input
              type="number"
              className="text-sm"
              placeholder="e.g. 10"
              value={getOptionValue('array.maxItems')}
              onChange={(e) => updateOptions('array.maxItems', e.target.value)}
            />
          </div>
          <div className="flex items-center space-x-2">
            <Checkbox
              id="array-unique"
              checked={!!getOptionValue('array.uniqueItems')}
              onCheckedChange={(checked) => updateOptions('array.uniqueItems', checked)}
            />
            <Label htmlFor="array-unique">
              Enforce unique items
            </Label>
          </div>
        </div>
      </div>
    );
  }

  if (type === 'object') {
    return (
      <div className="space-y-6">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            Object Options
          </h4>
          <p className="text-sm text-muted-foreground">
            Configure nested object field settings
          </p>
        </div>

        <div className="grid gap-4">
          <div className="space-y-2">
            <Label>Required Properties</Label>
            <Textarea
              className="min-h-[80px] resize-y font-mono text-sm"
              placeholder={`["firstName", "lastName", "email"]`}
              value={getOptionValue('object.required')}
              onChange={(e) => updateOptions('object.required', e.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              JSON array of required property names
            </p>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

function ConditionsEditor({
  field,
  onUpdateField,
}: {
  field: FieldType;
  onUpdateField: (updates: Partial<FieldType>) => void;
}) {
  const conditions = field.conditions || [];

  const addCondition = () => {
    const newConditions = [...conditions, { field: '', operator: 'equals', value: '' }];
    onUpdateField({ conditions: newConditions });
  };

  const removeCondition = (index: number) => {
    const newConditions = conditions.filter((_, index_) => index_ !== index);
    onUpdateField({ conditions: newConditions });
  };

  const updateCondition = (index: number, updates: any) => {
    const newConditions = [...conditions];
    newConditions[index] = { ...newConditions[index], ...updates };
    onUpdateField({ conditions: newConditions });
  };

  const operatorIcons = {
    equals: <Equal className="h-4 w-4" />,
    notEquals: <EqualNot className="h-4 w-4" />,
    contains: <Filter className="h-4 w-4" />,
    notContains: <FilterX className="h-4 w-4" />,
    greaterThan: <ChevronRight className="h-4 w-4" />,
    lessThan: <ChevronLeft className="h-4 w-4" />,
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h4 className="text-sm font-semibold tracking-tight">
            Conditional Logic
          </h4>
          <p className="text-xs text-muted-foreground">
            Define when this field should be shown
          </p>
        </div>
        <Button
          type="button"
          variant="ghost"
          onClick={addCondition}
          className="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium text-primary transition-colors hover:text-primary/80"
        >
          <Plus className="h-4 w-4" />
        </Button>
      </div>

      {conditions.length === 0 ? (
        <div className="rounded-md bg-muted/50 py-4 text-center text-xs text-muted-foreground">
          No conditions set
        </div>
      ) : (
        <div className="space-y-3">
          {conditions.map((condition, index) => (
            <div
              key={index}
              className="flex items-center gap-2 rounded-md bg-muted/50 p-3"
            >
              <Input
                className="flex-1 text-xs"
                placeholder="Field name"
                value={condition.field}
                onChange={(e) => updateCondition(index, { field: e.target.value })}
              />
              <Select
                value={condition.operator}
                onValueChange={(value: string) => updateCondition(index, { operator: value })}
              >
                <SelectTrigger className="w-[120px] p-1 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {Object.entries(operatorIcons).map(([value, icon]) => (
                    <SelectItem
                      key={value}
                      value={value}
                      className="flex items-center gap-2"
                    >
                      {icon}
                      <span className="capitalize">{value}</span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Input
                className="flex-1 text-xs"
                placeholder="Value"
                value={condition.value}
                onChange={(e) => updateCondition(index, { value: e.target.value })}
              />
              <button
                type="button"
                onClick={() => removeCondition(index)}
                className="p-2 text-muted-foreground transition-colors hover:text-destructive"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default DeploymentParametersForm;