import React, { createContext, ReactNode,useContext, useEffect, useState } from 'react';

interface HeaderContextType {
  headerContent: ReactNode | null;
  setHeaderContent: (content: ReactNode | null) => void;
}

const HeaderContext = createContext<HeaderContextType | undefined>(undefined);

export const HeaderProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [headerContent, setHeaderContent] = useState<ReactNode | null>(null);

  return (
    <HeaderContext.Provider value={{ headerContent, setHeaderContent }}>
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

export const Header: React.FC<{ children: ReactNode }> = ({ children }) => {
  const { setHeaderContent } = useHeader();

  useEffect(() => {
    setHeaderContent(children);
    return () => {
      setHeaderContent(null);
    };
  }, [children, setHeaderContent]);

  return null;
};

export const HeaderPortal: React.FC = () => {
  const { headerContent } = useHeader();

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

  return <>{headerContent}</>;
};

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
