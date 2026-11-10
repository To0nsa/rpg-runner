import { HttpsError } from "firebase-functions/v2/https";
import { requireObject } from "../ownership/validators.js";
import { boundedText } from "./validators.js";

export interface MessageText { title: string; body: string }
export interface MessageLocalization {
  schemaVersion: 1;
  translations: Record<string, MessageText>;
}

/** English remains in title/body. Sorted canonical locale tags make hashes order-independent. */
export function parseMessageLocalization(raw: unknown): MessageLocalization {
  const value = requireObject(raw, "localization");
  if (value.schemaVersion !== 1 || Object.keys(value).some((key) => !["schemaVersion", "translations"].includes(key))) {
    throw new HttpsError("invalid-argument", "Unsupported message localization.");
  }
  const entries = requireObject(value.translations, "translations");
  const locales = Object.keys(entries).sort();
  if (locales.length === 0 || locales.length > 8) throw new HttpsError("invalid-argument", "Use one to eight translations.");
  const translations: Record<string, MessageText> = {};
  for (const locale of locales) {
    if (locale === "en" || !/^[a-z]{2,3}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?$/.test(locale)) {
      throw new HttpsError("invalid-argument", "Use a canonical language, script and/or region tag; English uses title/body.");
    }
    const text = requireObject(entries[locale], "translation");
    if (Object.keys(text).some((key) => !["title", "body"].includes(key))) throw new HttpsError("invalid-argument", "Unknown translation field.");
    translations[locale] = { title: boundedText(text.title, "translated title", 120), body: boundedText(text.body, "translated body", 2000) };
  }
  return { schemaVersion: 1, translations };
}
