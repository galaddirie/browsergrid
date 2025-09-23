import React, { useState } from 'react';
import { Link, router } from '@inertiajs/react';
import { ArrowLeft, Chrome, Globe, Save } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Checkbox } from '@/components/ui/checkbox';
import Layout from '@/components/Layout';

interface ProfileFormData {
  name: string;
  description: string;
  browser_type: 'chrome' | 'chromium' | 'firefox';
  initialize: boolean;
}

export default function ProfilesNew() {
  const [formData, setFormData] = useState<ProfileFormData>({
    name: '',
    description: '',
    browser_type: 'chrome',
    initialize: true,
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleInputChange = (field: keyof ProfileFormData, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[field];
        return newErrors;
      });
    }
  };

  const validateForm = () => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Profile name is required';
    } else if (formData.name.length > 100) {
      newErrors.name = 'Profile name must be less than 100 characters';
    }

    if (formData.description && formData.description.length > 500) {
      newErrors.description = 'Description must be less than 500 characters';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);

    try {
      await router.post('/profiles', {
        profile: formData
      }, {
        onError: (errors: any) => {
          setErrors(errors);
        },
        onFinish: () => {
          setIsSubmitting(false);
        }
      });
    } catch (error) {
      console.error('Error creating profile:', error);
      setIsSubmitting(false);
    }
  };

  const BrowserOption = ({ value, label, icon: Icon, disabled = false }: { value: string; label: string; icon: any; disabled?: boolean }) => (
    <div className={`flex items-center space-x-3 ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}>
      <RadioGroupItem value={value} id={value} disabled={disabled} />
      <Label htmlFor={value} className={`flex items-center gap-2 ${disabled ? 'cursor-not-allowed' : 'cursor-pointer'}`}>
        <Icon className="h-5 w-5" />
        <span>{label}</span>
      </Label>
    </div>
  );

  return (
    <Layout>
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-6">
          <Button asChild variant="ghost" size="sm" className="mb-4">
            <Link href="/profiles">
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Profiles
            </Link>
          </Button>
          <h1 className="text-2xl font-semibold text-neutral-900">Create New Profile</h1>
          <p className="text-sm text-neutral-600 mt-1">
            Create a reusable browser profile to save cookies, local storage, and browser state
          </p>
        </div>

        {/* Form Content */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Profile Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Name */}
            <div className="space-y-2">
              <Label htmlFor="name">
                Profile Name <span className="text-red-500">*</span>
              </Label>
              <Input
                id="name"
                type="text"
                value={formData.name}
                onChange={(e) => handleInputChange('name', e.target.value)}
                placeholder="e.g., Production Testing, Client Demo"
                className={errors.name ? 'border-red-500' : ''}
              />
              {errors.name && (
                <p className="text-sm text-red-500">{errors.name}</p>
              )}
            </div>

            {/* Description */}
            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                value={formData.description}
                onChange={(e) => handleInputChange('description', e.target.value)}
                placeholder="Optional description of what this profile is used for"
                rows={3}
                className={errors.description ? 'border-red-500' : ''}
              />
              {errors.description && (
                <p className="text-sm text-red-500">{errors.description}</p>
              )}
            </div>

            {/* Browser Type */}
            <div className="space-y-3">
              <Label>Browser Type</Label>
              <RadioGroup
                value={formData.browser_type}
                onValueChange={(value: any) => handleInputChange('browser_type', value)}
              >
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div className="border rounded-lg p-4">
                    <BrowserOption value="chrome" label="Google Chrome" icon={Chrome} />
                  </div>
                  <div className="border rounded-lg p-4">
                    <BrowserOption value="chromium" label="Chromium" icon={Globe} />
                  </div>
                  <div className="border rounded-lg p-4">
                    <BrowserOption value="firefox" label="Firefox" icon={Globe} disabled={true} />
                    <p className="text-xs text-neutral-500 mt-2 ml-6">Coming soon</p>
                  </div>
                </div>
              </RadioGroup>
            </div>

            {/* Initialize Profile */}
            <div className="flex items-start space-x-3 p-4 bg-neutral-50 rounded-lg">
              <Checkbox
                id="initialize"
                checked={formData.initialize}
                onCheckedChange={(checked) => handleInputChange('initialize', !!checked)}
                className="mt-1"
              />
              <div className="flex-1">
                <Label htmlFor="initialize" className="cursor-pointer block">
                  Initialize with empty profile data
                </Label>
                <p className="text-xs text-neutral-600 mt-1">
                  Creates an empty profile structure. Uncheck if you plan to upload existing profile data.
                </p>
              </div>
            </div>

            {/* Info Box */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h4 className="text-sm font-semibold text-blue-900 mb-1">What are browser profiles?</h4>
              <p className="text-xs text-blue-800">
                Browser profiles save the complete state of a browser session including cookies, 
                local storage, session storage, and other browser data. This allows you to maintain 
                logged-in sessions, preferences, and other state across multiple browser sessions.
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex justify-end gap-3 mt-6">
          <Button
            type="button"
            variant="outline"
            onClick={() => router.visit('/profiles')}
            disabled={isSubmitting}
          >
            Cancel
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="bg-neutral-900 hover:bg-neutral-800"
          >
            {isSubmitting ? (
              <>Creating...</>
            ) : (
              <>
                <Save className="h-4 w-4 mr-2" />
                Create Profile
              </>
            )}
          </Button>
        </div>
      </div>
    </Layout>
  );
}