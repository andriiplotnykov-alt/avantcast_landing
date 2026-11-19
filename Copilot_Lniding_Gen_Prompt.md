# Avantcast — Copilot Implementation Prompt (Landing + Firebase)

Paste everything under the line **PROMPT START** into Copilot (agent mode). Attach: the Design Bible, screenshots of the three canvas boards, and the new logo file. Written in English because agents follow it more reliably; all customer-facing copy stays French (with EN dictionary).

**Verified before writing (Nov 2026):** `ybouane/liquidglass` is MIT. Paper Shaders shows Apache-2.0 on its repository today, but its changelog shows it was PolyForm Shield from v0.0.47 onward, so the prompt makes Copilot check the LICENSE of the exact version it installs. `paper-design/liquid-logo` is a demo app, not an npm package: the engine is the `LiquidMetal` component inside Paper Shaders, so the prompt uses that. The StarKnightt lens is a shadcn registry component and its licence was not verifiable: the prompt gates it behind a check and a feature flag. Two hard constraints of `ybouane/liquidglass` (glass elements must be direct children of its root; every capture is rasterised with html-to-image) shape the architecture below, so effects are placed deliberately, not everywhere.

---

## PROMPT START

# ROLE AND MISSION

You are a senior front-end and Firebase engineer. Build the production landing page for **Avantcast** (a personal-finance forecasting app, waitlist phase) in this repository. The visual direction is already designed: attached are the Design Bible and three board screenshots (desktop, hero close-up, mobile). The defining requirement is **iridescent liquid metal plus iridescent liquid glass as the identity of the whole site**, with real WebGL materials, not flat CSS cards. It must also be fast, accessible and secure.

**Working rules**

1. Work in milestones (section 12). After each milestone: run lint, typecheck and tests, commit with a clear message, and summarise what changed and what you want me to decide. Do not skip ahead.
2. **Never trust this prompt over the library's own README.** Before using any library, read its README or docs in `node_modules` (or its repo). If an API differs from what is written here, follow the README and record the difference in `docs/DECISIONS.md`.
3. Pin exact versions (no `^`) for the three effect libraries. Paper Shaders explicitly ships breaking changes under 0.0.x versions.
4. Do not invent product claims, testimonials, counters, urgency, bank-synchronisation promises, legal text, contact details or social accounts. If something is missing, use a clearly marked placeholder and list it in `docs/TODO-CONTENT.md`.
5. Every sample number on the page is illustrative and must be labelled "Exemple illustratif" in text (FR) / "Illustrative example" (EN).
6. Ask me before: adding any dependency not listed here, changing the data model, or deviating from the Bible.

# 1. STACK AND PROJECT SETUP (do these in order)

1. Create the app: `npx create-next-app@latest avantcast-landing --ts --tailwind --eslint --app --src-dir --import-alias '@/*'`.
2. Install runtime dependencies:
   - `npm i framer-motion zod next-intl firebase firebase-admin`
   - `npm i --save-exact @paper-design/shaders-react @ybouane/liquidglass` (then read the installed versions and each package's LICENSE file; write the result into `docs/LICENSES.md`).
3. Dev tools: `npm i -D @playwright/test @axe-core/playwright vitest firebase-tools`.
4. Fonts: load **Space Grotesk** (500, 700) and **Inter** (400, 500, 600) with `next/font/google` (self-hosted at build, `display: swap`). The glass library needs webfonts loaded before it initialises (see section 6).
5. Create `docs/DECISIONS.md`, `docs/TODO-CONTENT.md`, `docs/LICENSES.md`.
6. Folder structure:

```
src/app/[locale]/(site)/page.tsx            home
src/app/[locale]/(site)/{a-propos,confidentialite,assistance,faq}/page.tsx
src/app/api/waitlist/route.ts               server endpoint
src/components/fx/                          all WebGL and material code (client only)
src/components/ui/                          Button, Input, Badge, Modal, Accordion
src/components/sections/                    Hero, Constat, Demo, Features, Compare, How, Faq, Join, Footer
src/components/charts/ForecastChart.tsx     one reusable SVG chart component
src/lib/{firebase-admin.ts,waitlist.ts,capabilities.ts}
src/messages/{fr.json,en.json}
public/brand/                               logo masters (section 3)
functions/                                  Cloud Functions (Sheets sync)
```

# 2. DESIGN TOKENS (put in `globals.css` and the Tailwind theme before any component)

Colours: bg-0 #0A0714, bg-1 #120C24, footer #07040F, surface #1A1330, text-1 #F3EFFF, text-2 #B4ABD0, violet #8D6BE0 (history), violet-deep #7A56D6, magenta #D63A8C (projection), magenta-deep #C22C7E, blue #4A5FE0, cyan #5CE1E6, error #FF6B8A, success #4ADE9B. Border rgba(255,255,255,.14). Radii: input 14, card 22, panel 28, pill 999. Layout: 1280 max, 56 px side padding, 12-column grid. Spacing scale 4, 8, 12, 16, 24, 32, 48, 64, 96, 128. Type: H1 64/38, H2 42/28, body 17/16, label 11 uppercase tracking .12em. Easing `cubic-bezier(0.22, 1, 0.36, 1)`.

**Semantic rule of the whole site:** history is a **solid violet** line, projection is a **dashed magenta** line, the Today marker is a white dot with a dotted vertical line. Never swap.

# 3. LOGO PIPELINE (I will attach the new logo; it also replaces the old one everywhere)

The logo is an angular "A" chevron: a violet stroke whose last lower-right segment is magenta. Treat it as the Forecast Line made into a mark.

1. Redraw it as a clean vector master `public/brand/logo-master.svg` (keep the exact geometry of the attached file; miter joins; viewBox 0 0 64 64 or the attached proportions).
2. Export these assets from the master (scripted with `sharp` or Inkscape CLI, committed under `scripts/build-logo.mjs`):
   - `chevron-main.svg` and `chevron-projection.svg`: the two parts on **transparent backgrounds**, **same viewBox and same canvas size**, shape drawn in solid opaque black or white. The shader uses only the **alpha** channel as the shape mask. Add about 15% padding so edges are not clipped by the shader contour.
   - `chevron-mask-1024.png` of the whole mark (fallback).
   - `logo-flat.svg` two-colour (violet #8D6BE0, magenta #D63A8C), `favicon.svg`, `apple-touch-icon.png` (180), `og-image.png` (1200x630, built later from a screenshot of the hero).
3. **Find every use of the old logo** (`grep -ri 'logo' src public`), replace it with the new component, and delete the old files. Create one `<Logo variant='flat' | 'metal' size />` component used everywhere: flat SVG below 28 px, metal gradient above.
4. Wordmark "Avantcast" in Space Grotesk 700, tracking -0.02em, white. Never gradient-filled.

# 4. EFFECT LIBRARIES: ROLES (stick to this allocation)

| Library | Used for | Not used for |
| --- | --- | --- |
| `@paper-design/shaders-react` → `LiquidMetal` | The hero logo sculpture (two stacked layers) and, if budget allows, one metal divider | Buttons, cards, text |
| `@paper-design/shaders-react` → `MeshGradient` | The iridescent ambient light behind the hero and behind the Join section | Behind data panels |
| `@ybouane/liquidglass` | A **small number** of real refractive glass elements inside the hero stage: the e-mail capture pill and the floating KPI chip | The header, the modal, cards, the whole page |
| CSS "glass v2" recipe (section 7) | Header pill, cards, modal, form panel, footer details | n/a |
| StarKnightt `liquid-glass` (shadcn component) | **Optional** single signature moment (section 8), desktop only, behind a flag | Anything on mobile |
| `paper-design/liquid-logo` | Reference only. Do not install. Use the `LiquidMetal` component instead. | n/a |

**WebGL budget:** at most **3 concurrent WebGL contexts** on screen at any time (hero mesh, hero metal, glass root). Browsers cap contexts, and each Paper Shaders component and each LiquidGlass instance creates its own. Destroy or pause anything that scrolls out of view.

# 5. STEP BY STEP: PAPER SHADERS (hero sculpture and ambient light)

**5.1 Capability detection** (`src/lib/capabilities.ts`, client): return a tier:

- **Tier A (full):** WebGL2 available, `prefers-reduced-motion: no-preference`, `navigator.hardwareConcurrency >= 4`, not `connection.saveData`, viewport >= 1024 px.
- **Tier B (lite):** WebGL available but mobile/tablet or low power: one `LiquidMetal` layer with `speed` 0.25 and a capped `maxPixelCount`, no glass library, no mesh.
- **Tier C (static):** no WebGL, reduced motion, or data saver: static pre-rendered poster image of the sculpture plus CSS glow.

**5.2 Hero sculpture** (`src/components/fx/HeroSculpture.tsx`, `'use client'`). Stack two `LiquidMetal` layers at exactly the same size and position. Layer 1 uses `chevron-main.svg` with violet tint; layer 2 uses `chevron-projection.svg` with magenta tint. They do not overlap (the main mask excludes the magenta segment), which preserves the brand colour change.

```tsx
'use client';
import { LiquidMetal } from '@paper-design/shaders-react';

const base = { colorBack: '#00000000', repetition: 5, softness: 0.8, shiftRed: 0.3, shiftBlue: -0.3,
  distortion: 0.25, contour: 0.4, angle: 70, scale: 0.8, fit: 'contain' as const };

export function HeroSculpture({ size = 520, speed = 0.6 }: { size?: number; speed?: number }) {
  return (
    <div style={{ position: 'relative', width: size, height: size }} aria-hidden='true'>
      <LiquidMetal {...base} width={size} height={size} speed={speed}
        image='/brand/chevron-main.svg' colorTint='#8D6BE0' style={{ position: 'absolute', inset: 0 }} />
      <LiquidMetal {...base} width={size} height={size} speed={speed}
        image='/brand/chevron-projection.svg' colorTint='#D63A8C' style={{ position: 'absolute', inset: 0 }} />
    </div>
  );
}
```

Prop names above come from the current docs (`image`, `colorBack`, `colorTint`, `repetition`, `softness`, `shiftRed`, `shiftBlue`, `distortion`, `contour`, `angle`, `speed`, `scale`, `fit`). Verify them against the installed version. Then tune by eye against the board screenshots: target = chrome with crisp violet-white bands and visible prismatic fringes; the magenta segment reads as glass-like. Record final values in `docs/DECISIONS.md`.

**5.3 Load it safely.** Import with `next/dynamic` and `{ ssr: false }`, render a static poster (`chevron-mask-1024.png` with CSS glow) as the `loading` fallback and for Tier C, mount the shader only after first paint (`requestIdleCallback` or a short timeout), and fade it in over the poster (400 ms). Pass `aria-hidden` and give the poster `role='img'` with an alt text.

**5.4 Pause offscreen.** Wrap shader components in an `IntersectionObserver` hook: when less than 10% visible, set `speed={0}` (or unmount); resume on return. Also pause when `document.hidden`.

**5.5 Ambient light.** `MeshGradient` behind the hero (absolute, full bleed, `pointer-events: none`):

```tsx
<MeshGradient colors={['#0A0714', '#4A5FE0', '#8D6BE0', '#D63A8C']} distortion={0.9} swirl={0.6} speed={0.12}
  style={{ position: 'absolute', inset: 0, opacity: 0.55 }} />
```

Keep it dark, slow and subtle. Never place it behind charts or long text; add a dark gradient scrim above it so text contrast stays at least 4.5:1.

**5.6 Performance knobs.** Use the shader's `minPixelRatio` and `maxPixelCount` props to cap work on large screens; use the `frame` prop for a frozen frame in reduced-motion mode if it renders correctly, otherwise use the poster.

**5.7 Licence step.** Read `node_modules/@paper-design/shaders-react/LICENSE` for the installed version, copy the result to `docs/LICENSES.md`, and keep the NOTICE file. Add "Powered by Paper Shaders" in the footer if the licence asks for it (it is appreciated at minimum). Flag to me if the licence is PolyForm Shield, because that has competition restrictions.

# 6. STEP BY STEP: LIQUID GLASS (`@ybouane/liquidglass`)

**Know its constraints before coding (from its README):** glass elements must be **direct children** of the root; the library rasterises the root's other children with `html-to-image` and runs a WebGL shader over each glass element (refraction, blur, chromatic aberration, specular, Fresnel); webfonts must be loaded before `init()`; cross-origin images need `crossorigin='anonymous'`; each instance opens its own WebGL context; animated children need `data-dynamic` and that is expensive. Therefore apply it only to the **hero stage**.

**6.1 Hero stage structure.** Root = one `div` (the stage). Children, in this order: (1) a background layer (the sculpture and mesh), (2) static text, (3) the glass elements (e-mail pill, KPI chip).

**6.2 Spike first (30 minutes, report the result to me).** The library draws `<canvas>` and `<video>` children directly. A WebGL canvas may read as blank if its drawing buffer is not preserved. Test whether the Paper Shaders canvases appear inside the glass refraction. If not:

- Fallback A: record the hero (shader running) into a seamless looping `webm` plus `mp4`, use it as a `<video muted playsinline loop>` child of the stage (videos are auto-detected as dynamic). Keep the live shader only on Tier A desktop **above** the glass layer if needed.
- Fallback B: replace refraction on these two elements with the CSS glass recipe (section 7).

Document the chosen path in `docs/DECISIONS.md`.

**6.3 Initialise in a client component** (`src/components/fx/GlassStage.tsx`):

```tsx
'use client';
import { useEffect, useRef } from 'react';

export function GlassStage({ children }: { children: React.ReactNode }) {
  const root = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let instance: { destroy(): void } | undefined;
    let cancelled = false;
    (async () => {
      await document.fonts.ready;
      const { LiquidGlass } = await import('@ybouane/liquidglass');
      if (cancelled || !root.current) return;
      const glass = Array.from(root.current.querySelectorAll<HTMLElement>('[data-glass]'));
      glass.forEach((el) => { el.dataset.config = JSON.stringify({ cornerRadius: 999, blurAmount: 0.2,
        refraction: 0.7, chromAberration: 0.08, specular: 0.4, fresnel: 1, edgeHighlight: 0.2, shadowOpacity: 0.3 }); });
      instance = await LiquidGlass.init({ root: root.current, glassElements: glass });
    })();
    return () => { cancelled = true; instance?.destroy(); };
  }, []);
  return <div ref={root} style={{ position: 'relative' }}>{children}</div>;
}
```

The option names (`cornerRadius`, `blurAmount`, `refraction`, `chromAberration`, `specular`, `fresnel`, `edgeHighlight`, `shadowOpacity`, `floating`, `button`, `bevelMode`) come from the README. Keep text **inside** a glass element accessible: real `<input>` and `<button>` elements, and glass canvas decoration only. Use `button: true` for the CTA glass. Tier A only; Tiers B and C render the CSS glass recipe instead, so the page is identical in function. Tear down on unmount and on locale change.

# 7. THE CSS MATERIAL RECIPES (used everywhere else, and as fallbacks)

Implement these as Tailwind components or CSS classes in `globals.css`:

- **`.glass`**: iridescent frosted glass. Background `linear-gradient(135deg, rgba(255,255,255,.16), rgba(255,255,255,.04) 40%, rgba(141,107,224,.12))`, `backdrop-filter: blur(22px) saturate(1.5)`, inset highlights `inset 0 1px 0 rgba(255,255,255,.55)` and `inset 0 -24px 48px rgba(141,107,224,.14)`, shadow `0 24px 60px rgba(5,3,12,.55)`. Add a **1.2 px iridescent border** with a `::before` pseudo-element: `padding: 1.2px; background: conic-gradient(from 210deg, #5B7CFF, #5CE1E6, #8D6BE0, #D63A8C, #FFB3DA, #5B7CFF)` plus `mask` and `mask-composite: exclude` (with `-webkit-` prefixes) so only the border shows.
- **`.chrome-text`**: `background: linear-gradient(180deg, #fff 10%, #b9a6ff 38%, #3a2599 52%, #efe6ff 70%, #8d6be0); background-clip: text; color: transparent`. One or two key words per heading only.
- **`.chrome-rule`**: 2 px divider `linear-gradient(90deg, transparent, #fff, #8d6be0 30%, #d63a8c 70%, #fff, transparent)`.
- **Primary button**: gradient `110deg, #4A5FE0, #7A56D6 48%, #C22C7E`, 50 px high, pill, inset top highlight, glow `0 8px 30px rgba(194,44,126,.4)`, hover brightness +8% and lift 1 px, visible focus ring.
- **Phone mockups**: metal frame with `linear-gradient(145deg, #f3eeff, #6b55c9 25%, #1a1330 50%, #b7a3ff 78%, #4b31b0)`, radius 40, screens are **real React components** (not images) rendering the demo data with the shared `ForecastChart`.
- **Fallback** when `backdrop-filter` is unsupported: opaque `#1A1330` surface with the iridescent border kept.

Rule: never stack frosted glass over frosted glass, and never put effects over chart data (effects frame the data, they do not sit on it).

# 8. OPTIONAL SIGNATURE MOMENT (feature flag `NEXT_PUBLIC_FX_LENS`, default off)

Only after milestones 1 to 9 are done. Install the StarKnightt lens as a shadcn component: `npx shadcn@latest add https://starknightt.github.io/liquid-glass/r/liquid-glass.json` (it lands in `src/components/ui/liquid-glass.tsx`). **First check its licence** in its repository; if there is no licence file, do not ship it and tell me. It is a cursor-following WebGL2 lens that magnifies and refracts text beneath it, with props such as `lensRadius` and `magnification`. Use it for one thing only: a closing statement band above the Join section on desktop, pointer devices only, never on mobile or reduced motion. If it fights the page design or its own background, drop it and say so.

# 9. PAGE ASSEMBLY

Follow the Design Bible and the boards for exact specs. Homepage order: Header, Hero, Le constat (with bank-vs-Avantcast mini comparison), Démo, Fonctionnalités (four phones), Comparatif (Avantcast vs alternatives by category), Comment ça marche (3 steps plus privacy card), FAQ (4 accordion questions, native `<details>` or accessible accordion), Rejoindre (with 3 first-signup benefits, no counters), Footer. Secondary pages: À propos, Confidentialité, Assistance, FAQ.

- **Meaningful charts only.** One `ForecastChart` component with props for history, projection(s), Today index and an optional scenario line. No decorative graphs anywhere. History solid violet, projection dashed magenta, scenario dashed cyan. Draw-on animation uses `pathLength` (Framer Motion) once when in view.
- **Interactive demo:** a slider (0 to 400 EUR, step 50) changes the scenario line and the stated cumulative savings (monthly amount x 120 months; no return assumptions presented as expected). Use a real `<input type='range'>` with a label and `aria-valuetext`.
- **Comparison table:** use a real `<table>` with scope attributes; ✓ / \~ / — each with a visually hidden text label (oui, partiel, non). Keep the footnote saying it is an indicative category comparison. The Avantcast column must only claim built features: check `docs/TODO-CONTENT.md` flags with me.
- **Hero:** exactly one action: an inline e-mail field plus the button **"Je m'inscris"**. No secondary "Voir la démo" button (the Demo link stays in the nav). The KPI chip text is exactly **"Patrimoine net projeté"** (no trailing punctuation). Clicking the button opens the modal with the e-mail prefilled.

# 10. LANGUAGE SWITCH (FR default, EN)

Use `next-intl` with the `[locale]` segment (`/fr`, `/en`), default FR, middleware redirect on first visit using `Accept-Language`, then remember the choice in a cookie. The switch (FR | EN pill) sits at the top right of the header; it keeps the current page and hash, sets `lang` on `<html>`, and updates `hreflang` alternates and canonical URLs. Write `fr.json` first from the Bible copy, then a faithful `en.json`; mark EN strings that need my review. Nav labels: use French (Rejoindre, Démo, À propos, Confidentialité, Assistance, FAQ) unless I confirm the English labels. Do not translate the product name. All dates and numbers use `Intl` for the locale. The glass stage must re-initialise after a locale change.

# 11. WAITLIST: MODAL, API AND FIREBASE

**11.1 Modal** (accessible dialog, focus trapped, Esc to close, returns focus to the trigger; bottom sheet under 640 px): fields in this order: **E-mail** (required, prefilled from the hero), **Prénom** (optional), **Objectif financier principal** (optional select: Constituer une épargne de précaution, Acheter un bien, Préparer la retraite, Rembourser une dette, Faire croître mon patrimoine, Autre). Button "Confirmer mon inscription". States: idle, loading ("Inscription en cours…", 15 s timeout), success, duplicate ("Cette adresse est déjà enregistrée. Vous êtes bien sur la liste."), validation error per field, rate limited, server error with retry and no false success. Success screen: headline "Inscription confirmée.", the required English string `Waitlist joined successfully` kept as a constant used for the screen-reader announcement (`role='status'`), body text inviting people to the Discord, and a quieter "Rejoindre le Discord" button (new tab, `rel='noopener noreferrer'`, URL from env `NEXT_PUBLIC_DISCORD_URL`; hide the button if unset). Never show a position number or counter.

**11.2 Firebase setup (commands, in order):**

1. `firebase login` then `firebase init` (Firestore, Functions with TypeScript, Hosting or App Hosting for Next.js; ask me which hosting I want before choosing).
2. Enable **App Check** with reCAPTCHA Enterprise for the web app; integrate the client token in the request header; enforce it on the endpoint.
3. Firestore rules: `allow read, write: if false;` for every collection. Only server code writes.
4. Secrets: use Firebase secrets / Secret Manager (`firebase functions:secrets:set`) for the Google service account and sheet ID. Never place secrets in `NEXT_PUBLIC_*` variables or the client bundle.
5. Use the emulator suite for local work and tests.

**11.3 Data model** (collection `waitlist`): document ID = SHA-256 of the lower-cased, trimmed e-mail. Fields: `email`, `firstName` (optional), `goal` (optional enum), `locale` (`fr` or `en`), `source` (optional), `privacyNoticeVersion`, `createdAt` (**server timestamp**), `sheetSyncStatus` (`pending` | `synced` | `failed`), `sheetSyncAttempts`. This replaces the earlier "full name" field. Add nothing else without asking me. Do not store session duration per person: it may require consent. Use aggregate, cookie-light analytics only, and a consent banner only if non-exempt trackers are used.

**11.4 Endpoint** `POST /api/waitlist` (Next.js route handler with `firebase-admin`, or a callable function if I choose that hosting). Steps: verify the App Check token, parse with Zod, reject if the hidden honeypot field is filled (return a normal-looking success without writing), rate-limit per hashed IP (counter documents with a TTL), create the document inside a transaction (`create` fails if it exists, then return `duplicate`), respond only **after** the write succeeds.

```ts
const Body = z.object({
  email: z.string().trim().toLowerCase().email().max(254),
  firstName: z.string().trim().max(60).optional(),
  goal: z.enum(['safety', 'property', 'retirement', 'debt', 'growth', 'other']).optional(),
  locale: z.enum(['fr', 'en']),
  website: z.string().max(0).optional(), // honeypot
});
// responses: { status: 'created' | 'duplicate' | 'invalid' | 'rate_limited' | 'error' }
```

**11.5 Google Sheets sync (Cloud Function, 2nd gen)**: `onDocumentCreated('waitlist/{id}')` appends one row using a service account with access to that single sheet. On failure set `sheetSyncStatus: 'failed'`, retry with exponential backoff, and add a scheduled reconciliation function. A sync failure must never delete or hide a registration. **Neutralise spreadsheet formula injection:** prefix any value starting with `=`, `+`, `-` or `@` with a single quote before writing. The sheet is an operational view, Firestore is the source of truth.

**11.6 Do not write legal text.** Create placeholders for the privacy page and list in `docs/TODO-CONTENT.md` what a qualified person must supply: controller identity and contact, lawful basis, retention, data-subject rights, processors (Firebase, Google Sheets), Discord disclosure, whether a confirmation e-mail (double opt-in) is required. Do not claim GDPR compliance anywhere.

# 12. MILESTONES (stop and report after each)

1. Setup, tokens, fonts, i18n skeleton, docs files, licence audit.
2. Logo pipeline and `<Logo>`; remove old logo everywhere.
3. UI primitives and CSS materials (section 7), header with language switch.
4. Paper Shaders: capability tiers, `HeroSculpture`, `MeshGradient`, poster fallbacks, pause logic.
5. Glass spike (6.2), decision, then `GlassStage` with the e-mail pill and KPI chip.
6. `ForecastChart`, Demo, four phone mockups.
7. Constat, Comparatif, Comment ça marche, FAQ, Join, Footer.
8. Waitlist modal plus `/api/waitlist` plus Firestore plus App Check, tested against the emulator.
9. Sheets sync function and reconciliation.
10. Secondary pages, SEO (metadata, OG image, `hreflang`, sitemap, robots), accessibility pass.
11. Optional lens (section 8), performance pass, final QA.

# 13. QUALITY GATES (definition of done)

- **Performance:** Lighthouse mobile performance at least 85; LCP under 2.5 s with the poster; no layout shift from the shader mounting; at most 3 live WebGL contexts; shaders pause offscreen and when the tab is hidden; initial JS kept lean by lazy-loading every effect.
- **Accessibility:** axe has no serious violations; keyboard-only flow works end to end including modal and accordion; visible focus everywhere; 44 px touch targets; contrast at least 4.5:1 for text; `prefers-reduced-motion` produces Tier C visuals and instant transitions; charts have text summaries; history and projection are distinguishable without colour (solid vs dashed).
- **Resilience:** the page is fully usable with WebGL disabled; the waitlist works with JavaScript effects disabled; tested on Chrome, Safari and Firefox, iOS Safari and Android Chrome.
- **Security:** no secrets in the client bundle; Firestore rules deny all client access; App Check enforced; input validated server-side; headers set (CSP allowing only your own origins plus fonts, `Referrer-Policy`, `X-Content-Type-Options`).
- **Tests:** Playwright test for the waitlist flow (created, duplicate, invalid, rate limit, server error); axe test on each page; unit tests for hashing and validation.
- **Honesty:** every sample figure labelled illustrative; no invented claims, counters, testimonials or bank-sync promises; `docs/TODO-CONTENT.md` lists everything I still owe you.

Begin with milestone 1 and report back.

## PROMPT END
