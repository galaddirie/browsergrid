import React, { useState } from 'react';

import { SparklesIcon } from '@heroicons/react/24/solid';
import { useForm } from '@inertiajs/react';
import { Link } from '@inertiajs/react';
import { ChevronLeft, FolderOpen } from 'lucide-react';

import { Header } from '@/components/HeaderPortal';
import Layout from '@/components/Layout';
import { Card, CardContent } from '@/components/ui/card';
import { Label } from '@/components/ui/label';

import { ConfigureDeploymentForm } from './form-parts/content';
import { DeploymentParametersForm } from './form-parts/param';
import { DeploymentDetailsForm } from './form-parts/review';
import { UploadZipForm } from './form-parts/upload';

const Stepper = ({
  steps,
  currentStep,
}: {
  steps: string[];
  currentStep: number;
}) => {
  return (
    <div className="flex w-full flex-col items-start justify-start">
      {steps.map((step, index) => (
        <React.Fragment key={index}>
          <div className="flex items-start">
            <div className="m-0 flex flex-col items-center justify-start">
              <div
                className={`mt-[1px] mb-[1px] h-2 w-2 rounded-full ${
                  index <= currentStep
                    ? 'bg-blue-600 dark:bg-blue-400'
                    : 'bg-gray-300 dark:bg-gray-600'
                } flex items-center justify-center`}
              ></div>
              {index !== steps.length - 1 && (
                <div className="h-[32px] w-[1px] flex-grow bg-gray-200 dark:bg-gray-600" />
              )}
            </div>
            <span
              className={`relative top-[-6px] left-2 m-0 text-xs leading-6 font-medium ${
                index <= currentStep
                  ? 'text-blue-600 dark:text-blue-400'
                  : 'text-gray-500 dark:text-gray-400'
              }`}
            >
              {step}
            </span>
          </div>
        </React.Fragment>
      ))}
    </div>
  );
};

export default function DeploymentUpload() {
  const [step, setStep] = useState(0);
  const steps = [
    'Upload Archive',
    'Configure Deployment',
    'Deployment Parameters',
    'Finalize',
  ];

  const form = useForm({
    name: '',
    description: '',
    image: null as string | null,
    blurb: '',
    tags: [] as string[],
    is_public: false,
    archive: null as File | null,
    root_directory: './',
    install_command: '',
    start_command: '',
    environment_variables: [] as { key: string; value: string }[],
    parameters: [] as { key: string; label: string; description: string }[],
    package_parameters: {
      title: '',
      description: '',
      fields: [] as any[],
    },
  });

  const data = form.data;
  const setData = form.setData;
  const processing = form.processing;
  // @ts-expect-error - Avoiding deep type instantiation issue
  const errors = form.errors;
  const clearErrors = form.clearErrors;
  const setError = form.setError;

  const nextStep = () => {
    if (validateStep()) {
      setStep(previous => Math.min(previous + 1, steps.length - 1));
    }
  };

  const previousStep = () => {
    setStep(previous => Math.max(previous - 1, 0));
  };

  const validateStep = () => {
    clearErrors();

    switch (step) {
      case 0:
        if (!data.archive) {
          setError('archive', 'Please select a ZIP file to upload');
          return false;
        }
        return true;
      case 1:
        let isValid = true;
        if (!data.name) {
          setError('name', 'Deployment name is required');
          isValid = false;
        }
        if (!data.start_command) {
          setError('start_command', 'Start command is required');
          isValid = false;
        }
        return isValid;
      case 2:
        const packageFields = data.package_parameters.fields || [];
        const invalidFields = packageFields.some(
          (field: any, index: number) => {
            if (field.name || field.label) {
              if (!field.name) {
                setError(
                  `package_parameters.fields.${index}.name`,
                  'Field key is required',
                );
                return true;
              }
              if (!field.label) {
                setError(
                  `package_parameters.fields.${index}.label`,
                  'Field label is required',
                );
                return true;
              }
            }
            return false;
          },
        );

        const invalidParams = data.parameters.some((parameter, index) => {
          if (parameter.key || parameter.label || parameter.description) {
            if (!parameter.key) {
              setError(`parameters.${index}.key`, 'Parameter key is required');
              return true;
            }
            if (!parameter.label) {
              setError(
                `parameters.${index}.label`,
                'Parameter label is required',
              );
              return true;
            }
          }
          return false;
        });

        return !invalidFields && !invalidParams;
      default:
        return true;
    }
  };

  const onSubmit = () => {
    if (!validateStep()) {
      return;
    }

    form.transform(data => {
      const cleanedData = {
        ...data,
        environment_variables: data.environment_variables.filter(
          env => env.key && env.value,
        ),
        parameters: data.parameters.filter(
          parameter => parameter.key && parameter.label,
        ),
        tags: data.tags.filter(tag => tag.trim() !== ''),
      };

      if (data.package_parameters.fields) {
        cleanedData.package_parameters = {
          ...data.package_parameters,
          fields: data.package_parameters.fields.filter(
            (field: any) => field.name && field.label,
          ),
        };
      }

      return cleanedData;
    });

    form.post('/deployments', {
      preserveScroll: true,
      onSuccess: () => {
        console.log('Deployment created successfully');
      },
      onError: (errors: any) => {
        console.error('Upload failed:', errors);
      },
      onFinish: () => {
        console.log('Form submission finished');
      },
    });
  };

  const renderStep = () => {
    switch (step) {
      case 0:
        return (
          <UploadZipForm
            data={data}
            setData={setData}
            errors={errors}
            onNext={nextStep}
          />
        );
      case 1:
        return (
          <ConfigureDeploymentForm
            data={data}
            setData={setData}
            errors={errors}
            onNext={nextStep}
            onPrev={previousStep}
          />
        );
      case 2:
        return (
          <DeploymentParametersForm
            data={data}
            setData={setData}
            errors={errors}
            onNext={nextStep}
            onPrev={previousStep}
          />
        );
      case 3:
        return (
          <DeploymentDetailsForm
            data={data}
            errors={errors}
            processing={processing}
            onPrev={previousStep}
            onSubmit={onSubmit}
          />
        );
      default:
        return null;
    }
  };

  return (
    <Layout>
      <Header>
        <div className="flex flex-col items-start justify-start py-6">
          <Link
            href="/deployments"
            className="text-muted-foreground mb-4 flex items-center gap-2 text-sm hover:underline"
          >
            <ChevronLeft className="h-3 w-3" />
            Back to Deployments
          </Link>
          {step === 0 ? (
            <>
              <h1 className="mb-2 text-5xl font-bold">
                New Deployment{' '}
                <span className="relative top-[-10px] inline-flex items-center whitespace-nowrap">
                  <SparklesIcon className="ml-1 h-10 w-10 text-blue-500" />
                </span>
              </h1>
              <p className="text-primary/70 mb-6 text-sm">
                Upload and configure your browser automation project
              </p>
            </>
          ) : (
            <>
              <h1 className="mb-2 text-5xl font-bold">
                You're almost{' '}
                <span className="relative inline-flex items-center whitespace-nowrap text-blue-500">
                  done{' '}
                  <SparklesIcon className="relative top-[-10px] -ml-1 h-10 w-10 text-blue-500" />
                </span>
              </h1>
              <p className="text-primary/70 mb-6 text-sm">
                Upload and configure your browser automation project
              </p>
            </>
          )}
        </div>
      </Header>
      <div className="space-y-6">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
          <div className="space-y-6 lg:col-span-5">
            <Stepper steps={steps} currentStep={step} />

            <hr className="my-8 border-t" />

            {data.archive && (
              <>
                <div className="mb-4 text-sm font-semibold text-gray-600 dark:text-gray-400">
                  Uploaded File
                </div>
                <div className="flex flex-col gap-2 text-sm text-gray-500">
                  <div className="flex items-center gap-2">
                    <FolderOpen className="h-5 w-5" />
                    <span className="truncate font-mono">
                      {data.archive.name}
                    </span>
                  </div>
                </div>
              </>
            )}

            {step >= 1 && data.name && (
              <>
                <hr className="my-8 border-t" />
                <div className="mb-4 text-sm font-semibold text-gray-600 dark:text-gray-400">
                  Deployment Configuration
                </div>
                <div className="flex flex-col gap-2 text-sm text-gray-500">
                  <div className="flex items-center gap-2">
                    <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                      Name:
                    </Label>
                    <span className="font-mono">{data.name}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                      Root Directory:
                    </Label>
                    <span className="font-mono">{data.root_directory}</span>
                  </div>
                  {data.install_command && (
                    <div className="flex items-center gap-2">
                      <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                        Install:
                      </Label>
                      <span className="truncate font-mono">
                        {data.install_command}
                      </span>
                    </div>
                  )}
                  <div className="flex items-center gap-2">
                    <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                      Start:
                    </Label>
                    <span className="truncate font-mono">
                      {data.start_command}
                    </span>
                  </div>
                </div>
              </>
            )}
          </div>

          <div className="relative top-[-200px] lg:col-span-7">
            <Card className="p-0 shadow-xl">
              <CardContent className="flex min-h-[600px] flex-col p-6">
                {renderStep()}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </Layout>
  );
}
