const KEY = "scertta_surge_rules_v1";

export type SurgeRule = {
  id: string;
  name: string;
  multiplier: number;
  startsAt: string;
  endsAt: string;
  zoneLabel: string;
  zoneGeoJson: string;
  active: boolean;
};

function parse(raw: string | null): SurgeRule[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw) as unknown;
    if (!Array.isArray(v)) return [];
    return v.filter((x): x is SurgeRule => typeof x === "object" && x !== null);
  } catch {
    return [];
  }
}

export function loadSurgeRules(): SurgeRule[] {
  if (typeof window === "undefined") return [];
  return parse(localStorage.getItem(KEY));
}

export function saveSurgeRules(rules: SurgeRule[]) {
  if (typeof window === "undefined") return;
  localStorage.setItem(KEY, JSON.stringify(rules.slice(0, 100)));
}

export function addSurgeRule(rule: Omit<SurgeRule, "id">): SurgeRule {
  const full: SurgeRule = {
    ...rule,
    id: `sr-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
  };
  const list = [full, ...loadSurgeRules()];
  saveSurgeRules(list);
  return full;
}

export function removeSurgeRule(id: string) {
  saveSurgeRules(loadSurgeRules().filter((r) => r.id !== id));
}
