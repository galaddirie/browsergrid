import React, { useState } from 'react';
import { Link, router } from '@inertiajs/react';
import { Plus, User, Archive, Download, Upload, Trash2, Eye, HardDrive, Clock, Chrome, Globe } from 'lucide-react';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import Layout from '@/components/Layout';
import { Header } from '@/components/HeaderPortal';

// Type definitions
interface Profile {
  id: string;
  name: string;
  description?: string;
  browser_type: 'chrome' | 'chromium' | 'firefox';
  status: 'active' | 'archived' | 'updating' | 'error';
  storage_size_bytes?: number;
  last_used_at?: string;
  version: number;
  has_data: boolean;
  inserted_at: string;
  updated_at: string;
}

interface Stats {
  total: number;
  by_browser: Record<string, number>;
  by_status: Record<string, number>;
  active: number;
  total_storage_bytes: number;
}

interface ProfilesIndexProps {
  profiles: Profile[];
  total: number;
  stats: Stats;
}

// Status badge component
const StatusBadge = ({ status }: { status: string }) => {
  const getStatusColor = (status: string) => {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
      case 'archived':
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
      case 'updating':
        return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200';
      case 'error':
        return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
      default:
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
    }
  };

  return (
    <Badge className={`${getStatusColor(status)} border-0`}>
      {status}
    </Badge>
  );
};

// Browser icon component
const BrowserIcon = ({ browser }: { browser: string }) => {
  switch (browser) {
    case 'chrome':
      return <Chrome className="h-4 w-4 text-blue-600" />;
    case 'chromium':
      return <Globe className="h-4 w-4 text-green-600" />;
    case 'firefox':
      return <Globe className="h-4 w-4 text-orange-600" />;
    default:
      return <Globe className="h-4 w-4 text-gray-600" />;
  }
};

// Format bytes to human readable
const formatBytes = (bytes: number | undefined) => {
  if (!bytes) return 'N/A';
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  if (bytes === 0) return '0 Bytes';
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
};

export default function ProfilesIndex({ profiles, total, stats }: ProfilesIndexProps) {
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [profileToDelete, setProfileToDelete] = useState<Profile | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDeleteClick = (profile: Profile) => {
    setProfileToDelete(profile);
    setDeleteDialogOpen(true);
  };

  const handleDeleteConfirm = async () => {
    if (!profileToDelete) return;

    setIsDeleting(true);
    try {
      await router.delete(`/profiles/${profileToDelete.id}`, {
        onSuccess: () => {
          setDeleteDialogOpen(false);
          setProfileToDelete(null);
        },
        onError: () => {
          // Error will be handled by Inertia flash messages
        },
        onFinish: () => {
          setIsDeleting(false);
        }
      });
    } catch (error) {
      console.error('Error deleting profile:', error);
      setIsDeleting(false);
    }
  };

  const handleDeleteCancel = () => {
    setDeleteDialogOpen(false);
    setProfileToDelete(null);
  };

  const handleArchive = (profileId: string) => {
    router.post(`/profiles/${profileId}/archive`);
  };

  return (
    <Layout>
      <Header>
        <div>
          <h1 className="mb-2 text-4xl font-bold">Browser Profiles</h1>
          <p className="text-primary/70 mb-6 text-sm">
            Manage reusable browser profiles with saved state and configuration
          </p>
          <div className="mb-6">
            <Button
              size="sm"
              className="bg-neutral-900 hover:bg-neutral-800 text-white text-xs h-8"
              asChild
            >
              <Link href="/profiles/new">
                <Plus className="h-3 w-3 mr-1.5" />
                New Profile
              </Link>
            </Button>
          </div>
        </div>
      </Header>

      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="flex items-center gap-6 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Total:</span>
              <span className="font-semibold text-neutral-900">{stats.total}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Active:</span>
              <span className="font-semibold text-neutral-900">{stats.active}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-neutral-600">Storage:</span>
              <span className="font-semibold text-neutral-900">
                {formatBytes(stats.total_storage_bytes)}
              </span>
            </div>
            {Object.entries(stats.by_browser || {}).map(([browser, count]) => (
              <div key={browser} className="flex items-center gap-2">
                <BrowserIcon browser={browser} />
                <span className="font-semibold text-neutral-900">{count}</span>
              </div>
            ))}
          </div>
        )}

        {/* Profiles List */}
        <Card className="border-neutral-200/60">
          <CardHeader className="border-b border-neutral-100 bg-neutral-50/30 py-3">
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <h2 className="font-medium text-neutral-900">Profiles</h2>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {!profiles || profiles.length === 0 ? (
              <div className="text-center py-12">
                <User className="h-8 w-8 mx-auto text-neutral-400 mb-3" />
                <h3 className="text-sm font-semibold text-neutral-900 mb-1">No profiles yet</h3>
                <p className="text-xs text-neutral-600 mb-4">
                  Create your first browser profile to save and reuse browser state.
                </p>
                <Button
                  size="sm"
                  className="bg-neutral-900 hover:bg-neutral-800 text-white text-xs h-8"
                  asChild
                >
                  <Link href="/profiles/new">
                    <Plus className="h-3 w-3 mr-1.5" />
                    Create Profile
                  </Link>
                </Button>
              </div>
            ) : (
              <div className="divide-y divide-neutral-100">
                {profiles.map((profile) => (
                  <div
                    key={profile.id}
                    className="px-4 py-3 hover:bg-neutral-50/50 transition-colors duration-150"
                  >
                    <div className="flex items-center justify-between">
                      {/* Left side - Profile info */}
                      <div className="flex items-center gap-4 flex-1">
                        <div className="flex-shrink-0">
                          <div className="w-10 h-10 rounded-lg bg-neutral-100 flex items-center justify-center">
                            <BrowserIcon browser={profile.browser_type} />
                          </div>
                        </div>
                        
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2">
                            <h3 className="text-sm font-semibold text-neutral-900 truncate">
                              {profile.name}
                            </h3>
                            <StatusBadge status={profile.status} />
                            {profile.has_data && (
                              <HardDrive className="h-3 w-3 text-green-600" />
                            )}
                          </div>
                          {profile.description && (
                            <p className="text-xs text-neutral-600 mt-0.5 truncate">
                              {profile.description}
                            </p>
                          )}
                          <div className="flex items-center gap-4 mt-1 text-xs text-neutral-500">
                            <span className="capitalize">{profile.browser_type}</span>
                            <span>v{profile.version}</span>
                            <span>{formatBytes(profile.storage_size_bytes)}</span>
                            <span className="flex items-center gap-1">
                              <Clock className="h-3 w-3" />
                              {profile.last_used_at
                                ? new Date(profile.last_used_at).toLocaleDateString()
                                : 'Never used'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Right side - Actions */}
                      <div className="flex items-center gap-1 ml-4">
                        <Button
                          size="sm"
                          variant="ghost"
                          asChild
                          className="h-7 w-7 p-0 hover:bg-neutral-100"
                        >
                          <Link href={`/profiles/${profile.id}`}>
                            <Eye className="h-3 w-3" />
                          </Link>
                        </Button>
                        {profile.has_data && (
                          <Button
                            size="sm"
                            variant="ghost"
                            asChild
                            className="h-7 w-7 p-0 hover:bg-neutral-100"
                            title="Download profile data"
                          >
                            <a href={`/profiles/${profile.id}/download`}>
                              <Download className="h-3 w-3" />
                            </a>
                          </Button>
                        )}
                        {profile.status === 'active' && (
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => handleArchive(profile.id)}
                            className="h-7 w-7 p-0 hover:bg-neutral-100"
                            title="Archive profile"
                          >
                            <Archive className="h-3 w-3" />
                          </Button>
                        )}
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => handleDeleteClick(profile)}
                          className="h-7 w-7 p-0 text-red-600 hover:bg-red-50"
                          title="Delete profile"
                        >
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Delete Profile</DialogTitle>
            <DialogDescription>
              Are you sure you want to delete the profile "{profileToDelete?.name}"?
              This action cannot be undone and will delete all associated snapshots and data.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={handleDeleteCancel}
              disabled={isDeleting}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteConfirm}
              disabled={isDeleting}
            >
              {isDeleting ? 'Deleting...' : 'Delete'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Layout>
  );
}