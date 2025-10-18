import { cn } from '@/lib/utils';
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

interface HeaderContextType {
  headerContent: ReactNode | null;
  setHeaderContent: (content: ReactNode | null) => void;
  headerClassName: string | undefined;
  setHeaderClassName: (className: string | undefined) => void;
}

const HeaderContext = createContext<HeaderContextType | undefined>(undefined);

export const HeaderProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [headerContent, setHeaderContent] = useState<ReactNode | null>(null);
  const [headerClassName, setHeaderClassName] = useState<string | undefined>(undefined);

  return (
    <HeaderContext.Provider value={{ headerContent, setHeaderContent, headerClassName, setHeaderClassName }}>
      {children}
    </HeaderContext.Provider>
  );
};

export const useHeader = () => {
  const context = useContext(HeaderContext);
  if (context === undefined) {
    throw new Error('useHeader must be used within a HeaderProvider');
  }
  return context;
};

/**
 * Header component for setting header content in the portal
 * @param children - Content to display in the header
 * @param className - Optional className to apply to the header container
 */
export const Header: React.FC<{ children: ReactNode; className?: string }> = ({ children, className }) => {
  const { setHeaderContent, setHeaderClassName } = useHeader();

  useEffect(() => {
    setHeaderContent(children);
    setHeaderClassName(className);
    return () => {
      setHeaderContent(null);
      setHeaderClassName(undefined);
    };
  }, [children, className, setHeaderContent, setHeaderClassName]);

  return null;
};

/**
 * HeaderPortal component that renders the header content
 * Falls back to default Browsergrid branding if no content is set
 */
export const HeaderPortal: React.FC = () => {
  const { headerContent, headerClassName } = useHeader();

  if (!headerContent) {
    return (
      <div>
        <h1 className="mb-2 text-4xl font-bold">Browsergrid</h1>
        <p className="text-primary/70 mb-6 text-sm">
          Browser infrastructure for automation, testing, and development
        </p>
      </div>
    );
  }

  return <div className={cn(headerClassName, 'w-full h-full')}>{headerContent}</div>;
};

/**
 * useSetHeader hook for programmatically setting header content
 * Useful for setting headers with title, description, and actions
 */
export const useSetHeader = (content: { title: string; description: string; actions?: ReactNode } | null) => {
  const { setHeaderContent } = useHeader();

  useEffect(() => {
    if (!content) {
      setHeaderContent(null);
      return;
    }

    setHeaderContent(
      <div>
        <h1 className="mb-2 text-4xl font-bold">{content.title}</h1>
        <p className="text-primary/70 mb-6 text-sm">
          {content.description}
        </p>
        {content.actions && (
          <div className="mb-6 flex space-x-2">
            {content.actions}
          </div>
        )}
      </div>
    );
    return () => {
      setHeaderContent(null);
    };
  }, [content?.title, content?.description, setHeaderContent]);
};