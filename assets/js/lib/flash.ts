/**
 * Flash message utility functions for clearing Phoenix flash messages
 * from React components using the Flash API.
 */

/**
 * Clear a specific flash message type
 * @param type - The flash message type to clear ('info', 'error', 'warning', 'notice')
 * @returns Promise that resolves when the flash message is cleared
 */
export const clearFlash = async (type: 'info' | 'error' | 'warning' | 'notice'): Promise<void> => {
  try {
    const response = await fetch(`/api/v1/flash/${type}`, { 
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to clear flash message: ${response.statusText}`);
    }
  } catch (error) {
    console.error('Error clearing flash message:', error);
  }
};

/**
 * Clear all flash messages at once
 * @returns Promise that resolves when all flash messages are cleared
 */
export const clearAllFlash = async (): Promise<void> => {
  try {
    const response = await fetch('/api/v1/flash', { 
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to clear flash messages: ${response.statusText}`);
    }
  } catch (error) {
    console.error('Error clearing flash messages:', error);
  }
};

/**
 * Flash message types that match Phoenix flash message conventions
 */
export type FlashType = 'info' | 'error' | 'warning' | 'notice';

/**
 * Flash message structure as received from Phoenix via Inertia
 */
export interface FlashMessages {
  info?: string;
  error?: string;
  warning?: string;
  notice?: string;
}
