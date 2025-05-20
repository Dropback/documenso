import { createContext, useContext } from 'react';

type BrandingContextValue = {
  brandingEnabled: boolean;
  brandingUrl: string;
  brandingLogo: string;
  brandingCompanyDetails: string;
  brandingHidePoweredBy: boolean;
};

const BrandingContext = createContext<BrandingContextValue | undefined>(undefined);

const defaultBrandingContextValue: BrandingContextValue = {
  brandingEnabled: false,
  brandingUrl: '',
  brandingLogo: '',
  brandingCompanyDetails: '',
  brandingHidePoweredBy: false,
};

const dropbackBrandingContextValue: BrandingContextValue = {
  brandingEnabled: true,
  brandingUrl: 'https://www.dropback.com/',
  brandingLogo:
    'https://cdn.prod.website-files.com/6765ae74882175bf8d1ad94b/676600778b9fa0efd05df716_dropback-long-black-p-2000.png',
  brandingCompanyDetails: 'Dropback, Inc.',
  brandingHidePoweredBy: true,
};

export const BrandingProvider = (props: {
  branding?: BrandingContextValue;
  children: React.ReactNode;
}) => {
  return (
    <BrandingContext.Provider value={dropbackBrandingContextValue}>
      {props.children}
    </BrandingContext.Provider>
  );
};

export const useBranding = () => {
  const ctx = useContext(BrandingContext);

  if (!ctx) {
    throw new Error('Branding context not found');
  }

  return ctx;
};

export type BrandingSettings = BrandingContextValue;
