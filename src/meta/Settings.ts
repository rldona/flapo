/**
 * Port de `settings.gd`: preferencias que no son progreso (silencio, fantasma).
 * Separado del guardado a propósito: borrar la partida no desactiva el mute.
 */
const KEY = 'flapo.settings.v1';

interface SettingsData {
  muted: boolean;
  ghost_hidden: boolean;
}

const DEFAULTS: SettingsData = { muted: false, ghost_hidden: false };

function datos(): SettingsData {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ...DEFAULTS };
    const parsed = JSON.parse(raw) as Partial<SettingsData>;
    return {
      muted: typeof parsed.muted === 'boolean' ? parsed.muted : DEFAULTS.muted,
      ghost_hidden:
        typeof parsed.ghost_hidden === 'boolean' ? parsed.ghost_hidden : DEFAULTS.ghost_hidden,
    };
  } catch {
    return { ...DEFAULTS };
  }
}

function guardar(d: SettingsData): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(d));
  } catch {
    /* ignore */
  }
}

export const Settings = {
  isMuted(): boolean {
    return datos().muted;
  },
  setMuted(muted: boolean): boolean {
    guardar({ ...datos(), muted });
    return muted;
  },
  isGhostHidden(): boolean {
    return datos().ghost_hidden;
  },
  setGhostHidden(oculto: boolean): boolean {
    guardar({ ...datos(), ghost_hidden: oculto });
    return oculto;
  },
  clear(): void {
    try {
      localStorage.removeItem(KEY);
    } catch {
      /* ignore */
    }
  },
};
