import Layout from '@/components/Layout';
import { Header } from '@/components/HeaderPortal';
import { PoolForm } from '@/components/pools/PoolForm';
import { Profile, SessionPoolFormValues } from '@/types';

interface PoolsNewProps {
  form: SessionPoolFormValues;
  profiles: Profile[];
  errors: Record<string, string>;
}

export default function PoolsNew({ form, profiles, errors }: PoolsNewProps) {
  return (
    <Layout>
      <Header>
        <div>
          <h1 className="mb-2 text-4xl font-bold">Create Session Pool</h1>
          <p className="text-primary/70 text-sm">
            Define a pool template, ready capacity, and lifecycle targets.
          </p>
        </div>
      </Header>

      <div className="py-6">
        <PoolForm
          action="create"
          initialValues={form}
          profiles={profiles}
          errors={errors}
        />
      </div>
    </Layout>
  );
}
