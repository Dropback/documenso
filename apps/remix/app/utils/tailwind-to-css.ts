/**
 * Re-export from tw-to-css, which is a CommonJS module.
 * This fixes ESM/CommonJS compatibility issues.
 */
import twToCss from 'tw-to-css';

// Export default for users who want the whole module
export default twToCss;

// Export named functions for those who want specific parts
export const tailwindToCSS = twToCss.tailwindToCSS;
