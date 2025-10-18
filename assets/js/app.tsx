import { createInertiaApp } from '@inertiajs/react';
import axios from 'axios';
import { createRoot } from 'react-dom/client';

import { HeaderProvider } from './components/HeaderPortal';
import { ThemeProvider } from './components/theme-provider';
import DeploymentsIndex from './pages/Deployments/Index';
import DeploymentsNew from './pages/Deployments/New';
import DeploymentsShow from './pages/Deployments/Show';
import Overview from './pages/Overview';
import ProfilesIndex from './pages/Profiles/Index';
import ProfilesNew from './pages/Profiles/New';
import PoolsIndex from './pages/Pools/Index';
import PoolsNew from './pages/Pools/New';
import PoolsShow from './pages/Pools/Show';
import SessionsEdit from './pages/Sessions/Edit';
import SessionsIndex from './pages/Sessions/Index';
import SessionsShow from './pages/Sessions/Show';
import Account from './pages/Settings/Account';
import ApiTokens from './pages/Settings/ApiTokens';
import { ComponentType } from 'react';

axios.defaults.xsrfHeaderName = 'x-csrf-token';

const pages: Record<string, ComponentType<any>> = {
   
  Overview: Overview,
  'Deployments/Index': DeploymentsIndex,
  'Deployments/New': DeploymentsNew,
  'Deployments/Show': DeploymentsShow,
  'Profiles/Index': ProfilesIndex,
  'Profiles/New': ProfilesNew,
  'Pools/Index': PoolsIndex,
  'Pools/New': PoolsNew,
  'Pools/Show': PoolsShow,
  'Sessions/Index': SessionsIndex,
  'Sessions/Show': SessionsShow,
  'Sessions/Edit': SessionsEdit,
  'Settings/Account': Account,
  'Settings/ApiTokens': ApiTokens,
};

createInertiaApp({
  resolve: (name: string) => {
    const page = pages[name];
    if (!page) {
      throw new Error(`Page not found: ${name}`);
    }
    return page;
  },
  setup({ App, el, props }) {
    createRoot(el).render(
      <ThemeProvider defaultTheme="system" storageKey="browsergrid-ui-theme">
        <HeaderProvider>
          <App {...props} />
        </HeaderProvider>
      </ThemeProvider>,
    );
  },
});
