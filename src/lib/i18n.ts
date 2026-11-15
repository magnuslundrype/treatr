/**
 * Oversatte tekster ligger i databasen som jsonb: {"es": "...", "en": "...", "da": "..."}.
 * Samme fallback-rækkefølge som SQL-funktionen public.i18n(): ønsket sprog → en → es → da.
 */
export const LOCALES = ["es", "en", "da"] as const;
export type Locale = (typeof LOCALES)[number];
export type Translated = Partial<Record<Locale, string>>;

const FALLBACK_ORDER: readonly Locale[] = ["en", "es", "da"];

export function isLocale(value: unknown): value is Locale {
  return typeof value === "string" && (LOCALES as readonly string[]).includes(value);
}

export function pickLocale(text: Translated | null | undefined, locale: Locale): string {
  if (!text) return "";
  for (const candidate of [locale, ...FALLBACK_ORDER]) {
    const value = text[candidate];
    if (value) return value;
  }
  return "";
}
