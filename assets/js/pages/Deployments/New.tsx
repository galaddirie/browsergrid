import React, { useState } from 'react';
import { useForm } from '@inertiajs/react';
import { FolderOpen, ChevronLeft } from 'lucide-react';
import { Link } from '@inertiajs/react';
import { SparklesIcon } from '@heroicons/react/24/solid';
import { Card, CardContent } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import Layout from '@/components/Layout';
import { UploadZipForm } from './form-parts/upload';
import { ConfigureDeploymentForm } from './form-parts/content';
import { DeploymentParametersForm } from './form-parts/param';
import { DeploymentDetailsForm } from './form-parts/review';
import { Header } from '@/components/HeaderPortal';
  
const Stepper = ({ steps, currentStep }: { steps: string[], currentStep: number }) => {
  return (
    <div className="flex flex-col items-start justify-start w-full">
      {steps.map((step, index) => (
        <React.Fragment key={index}>
          <div className="flex items-start">
            <div className="flex flex-col items-center justify-start m-0">
              <div className={`w-2 h-2 mt-[1px] mb-[1px] rounded-full ${index <= currentStep
                ? 'bg-blue-600 dark:bg-blue-400'
                : 'bg-gray-300 dark:bg-gray-600'
                } flex items-center justify-center`}>
              </div>
              {index !== steps.length - 1 && (
                <div className="flex-grow h-[32px] bg-gray-200 dark:bg-gray-600 w-[1px]" />
              )}
            </div>
            <span className={`relative font-medium text-xs m-0 top-[-6px] leading-6 left-2 ${index <= currentStep
              ? 'text-blue-600 dark:text-blue-400'
              : 'text-gray-500 dark:text-gray-400'
              }`}>
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
  const steps = ['Upload Archive', 'Configure Deployment', 'Deployment Parameters', 'Finalize'];



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
    environment_variables: [] as { key: string; value: string; }[],
    parameters: [] as { key: string; label: string; description: string; }[],
    package_parameters: {
      title: '',
      description: '',
      fields: [] as any[]
    }
  });

  const data = form.data;
  const setData = form.setData;
  const processing = form.processing;
  // @ts-ignore - Avoiding deep type instantiation issue
  const errors = form.errors;
  const clearErrors = form.clearErrors;
  const setError = form.setError;

  const nextStep = () => {
    if (validateStep()) {
      setStep(prev => Math.min(prev + 1, steps.length - 1));
    }
  };

  const prevStep = () => {
    setStep(prev => Math.max(prev - 1, 0));
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
        const invalidFields = packageFields.some((field: any, index: number) => {
          if (field.name || field.label) {
            if (!field.name) {
              setError(`package_parameters.fields.${index}.name`, 'Field key is required');
              return true;
            }
            if (!field.label) {
              setError(`package_parameters.fields.${index}.label`, 'Field label is required');
              return true;
            }
          }
          return false;
        });
        
        const invalidParams = data.parameters.some((param, index) => {
          if (param.key || param.label || param.description) {
            if (!param.key) {
              setError(`parameters.${index}.key`, 'Parameter key is required');
              return true;
            }
            if (!param.label) {
              setError(`parameters.${index}.label`, 'Parameter label is required');
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

    form.transform((data) => {
      const cleanedData = {
        ...data,
        environment_variables: data.environment_variables.filter(env => env.key && env.value),
        parameters: data.parameters.filter(param => param.key && param.label),
        tags: data.tags.filter(tag => tag.trim() !== ''),
      };

      if (data.package_parameters.fields) {
        cleanedData.package_parameters = {
          ...data.package_parameters,
          fields: data.package_parameters.fields.filter((field: any) => field.name && field.label)
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
      }
    });
  };

  const renderStep = () => {
    switch (step) {
      case 0:
        return <UploadZipForm data={data} setData={setData} errors={errors} onNext={nextStep} />;
      case 1:
        return <ConfigureDeploymentForm data={data} setData={setData} errors={errors} onNext={nextStep} onPrev={prevStep} />;
      case 2:
        return <DeploymentParametersForm data={data} setData={setData} errors={errors} onNext={nextStep} onPrev={prevStep} />;
      case 3:
        return <DeploymentDetailsForm data={data} errors={errors} processing={processing} onPrev={prevStep} onSubmit={onSubmit} />;
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
            className="mb-4 flex items-center gap-2 text-sm text-muted-foreground hover:underline"
          >
            <ChevronLeft className="h-3 w-3" />
            Back to Deployments
          </Link>
          {step === 0 ?(
            <>
              <h1 className="text-5xl font-bold mb-2">
              New Deployment{' '}
              <span className="inline-flex items-center whitespace-nowrap relative top-[-10px]">
                <SparklesIcon className="ml-1 h-10 w-10 text-blue-500" />
              </span>
            </h1>
            <p className="text-primary/70 mb-6 text-sm">
              Upload and configure your browser automation project
            </p>
    
            </>
          ) : (
            <>  
            <h1 className="text-5xl font-bold mb-2">
              You're almost{' '}
              <span className="inline-flex items-center whitespace-nowrap relative text-blue-500 ">
                done <SparklesIcon className="-ml-1 h-10 w-10 text-blue-500 top-[-10px] relative" />
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
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          <div className="lg:col-span-5 space-y-6">
            

            <Stepper steps={steps} currentStep={step} />

            <hr className="border-t my-8" />

            {data.archive && (
              <>
                <div className="text-sm font-semibold text-gray-600 dark:text-gray-400 mb-4">
                  Uploaded File
                </div>
                <div className="flex flex-col gap-2 text-sm text-gray-500">
                  <div className="flex items-center gap-2">
                    <FolderOpen className="w-5 h-5" />
                    <span className="font-mono truncate">
                      {data.archive.name}
                    </span>
                  </div>
                </div>
              </>
            )}

            {(step >= 1 && data.name) && (
              <>
                <hr className="border-t my-8" />
                <div className="text-sm font-semibold text-gray-600 dark:text-gray-400 mb-4">
                  Deployment Configuration
                </div>
                <div className="flex flex-col gap-2 text-sm text-gray-500">
                  <div className="flex items-center gap-2">
                    <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                      Name:
                    </Label>
                    <span className="font-mono">
                      {data.name}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                      Root Directory:
                    </Label>
                    <span className="font-mono">
                      {data.root_directory}
                    </span>
                  </div>
                  {data.install_command && (
                    <div className="flex items-center gap-2">
                      <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                        Install:
                      </Label>
                      <span className="font-mono truncate">
                        {data.install_command}
                      </span>
                    </div>
                  )}
                  <div className="flex items-center gap-2">
                    <Label className="text-xs font-semibold text-gray-600 dark:text-gray-400">
                      Start:
                    </Label>
                    <span className="font-mono truncate">
                      {data.start_command}
                    </span>
                  </div>
                </div>
              </>
            )}
          </div>

          <div className="lg:col-span-7 relative top-[-200px]">
            <Card className="shadow-xl p-0">
              <CardContent className="p-6 min-h-[600px] flex flex-col">
                {renderStep()}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </Layout>
  );
}