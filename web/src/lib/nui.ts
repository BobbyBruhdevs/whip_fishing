// Talking to the Lua side. In a plain browser (vite dev) there is no game: calls are logged and skipped.

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export const inGame = typeof window.GetParentResourceName === 'function';
const resource = inGame ? window.GetParentResourceName!() : 'whip_fishing';

export async function nuiCallback<T = unknown>(name: string, data: unknown = {}): Promise<T | null> {
  if (!inGame) {
    console.debug('[nui]', name, data);
    return null;
  }
  try {
    const res = await fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return (await res.json()) as T;
  } catch {
    return null;
  }
}
