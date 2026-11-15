import { describe, expect, it } from "vitest";
import { isLocale, pickLocale } from "./i18n";

describe("pickLocale", () => {
  const text = { es: "Chef privado", en: "Private chef", da: "Privat kok" };

  it("returns the requested language when it exists", () => {
    expect(pickLocale(text, "da")).toBe("Privat kok");
  });

  it("falls back to English, then Spanish", () => {
    expect(pickLocale({ es: "Chef privado", en: "Private chef" }, "da")).toBe("Private chef");
    expect(pickLocale({ es: "Chef privado" }, "da")).toBe("Chef privado");
  });

  it("returns an empty string when nothing is translated", () => {
    expect(pickLocale(null, "en")).toBe("");
    expect(pickLocale({}, "en")).toBe("");
  });
});

describe("isLocale", () => {
  it("accepts only es, en and da", () => {
    expect(isLocale("es")).toBe(true);
    expect(isLocale("fr")).toBe(false);
    expect(isLocale(undefined)).toBe(false);
  });
});
