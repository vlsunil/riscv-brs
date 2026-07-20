# Antora Build Guide (BRS)

How this repo produces **both** the ARC-compliant submission PDF and the
Antora static-site HTML from a **single source tree**, for the BRS spec only
— the BRS Test Specification is PDF-only (see "Two documents, one Antora
component" below).

## TL;DR for authors

- BRS spec chapter content lives once, in `modules/ROOT/pages/*.adoc`, as
  standalone Antora pages (each starts with a level-0 `= Title`).
- `src/brs.adoc` is a thin **PDF assembler**: it includes those pages with
  `leveloffset=+1` so their level-0 titles become chapters in the PDF,
  reproducing the historical section numbering (including the
  "Firmware Implementation Guidance" section — see below).
- `src/brs-ts.adoc` is the BRS Test Specification assembler; its content
  (`brs_ts_intro.adoc`, `brs_tests.adoc`) is **not** promoted to Antora pages.
- Build the PDFs: `make build-brs` / `make build-brs-ts` →
  `build/<short>-v<ver>-<YYYYMMDD>.pdf`.
- Build the site locally: `npm run preview` (needs `docker compose up -d
  kroki` first) → `build/site/`.

## The dual-source technique (why it works)

The PDF wants one master document; Antora wants one file per navigable page.
`leveloffset=+1` reconciles them:

```
modules/ROOT/pages/intro.adoc        src/brs.adoc (PDF assembler)
-----------------------------        -----------------------------------
= Introduction        (level 0)  ->  include::../modules/ROOT/pages/intro.adoc[leveloffset=+1]
== Releases           (level 1)      => renders as "== Introduction" (Ch.)
                                        and "=== Releases" (sub-section)
```

So the pages are the single content source; the assembler is PDF-only glue.
PDF-only constructs stay in the assembler and never appear in a page:
- the "Document State" preface and `toc::[]` placement
- the back-of-book `[index] == Index` macro (Antora generates no index)
- `:title-logo-image:`, `:pdf-style:`, `:pdf-fontsdir:`, `:doctype: book`, etc.
- the "Firmware Implementation Guidance" wrapper section, which includes
  `non-normative/{recipes,uefi,acpi,smbios}.adoc` — distinct, guidance-specific
  content (not a second copy of the `modules/ROOT/pages/*` chapters) that has
  no standalone identity of its own, so it has no corresponding Antora page
  and stays assembler-only glue.

## ACPI: page + partials

`modules/ROOT/pages/acpi.adoc` is a promoted page (its own headings shifted
down one level, `==`→`=`, `===`→`==`), but it nests three single-use fragments
that stay in `modules/ROOT/partials/` at their **original**, unedited heading
levels (`acpi-id.adoc`, `acpi-prop.adoc`, `acpi-trace.adoc`). Since the page
shifted but the partials did not, `acpi.adoc`'s own `include::` lines for
those partials carry `leveloffset=-1` to cancel the page-level shift and keep
the partials as siblings of "BRS-I ACPI Methods and Objects", both when the
page renders standalone (Antora) and when the assembler includes it via
`src/brs.adoc` with its own `leveloffset=+1` — the two offsets sum correctly
in both directions. (The separate ACPI *Guidance* subsection under "Firmware
Implementation Guidance" is unrelated content from `non-normative/acpi.adoc`,
not a second inclusion of this page.)

## Two documents, one Antora component

This repo carries two independently-versioned documents:

- **BRS spec** (Ratified, tagged `v0.0.1`–`v1.0`) — has the full Antora
  treatment above; it is the repo's single Antora component (`name: brs` in
  `antora.yml`).
- **BRS Test Specification** (Draft, revnumber `0.1`, untracked by tags) —
  stays PDF-only. Its Draft/untagged lineage doesn't fit Antora's
  "one static version per component" model, and promoting it to a real Antora
  component is a bigger decision than this migration made unilaterally. Its
  content (`brs_ts_intro.adoc`, `brs_tests.adoc`) is included directly by
  `src/brs-ts.adoc`, unchanged, exactly as before this migration.

See the Makefile for how the two documents' versions resolve independently
(`VERSION_brs` from git tags; `VERSION_brs-ts` static, hand-bumped).

## Repository layout

```
antora.yml                       # component descriptor (keep MINIMAL — see below)
antora-playbook.yml              # LOCAL preview playbook (mirrors production UI)
modules/ROOT/
  nav.adoc                       # site navigation (BRS spec only)
  pages/                         # single source of BRS spec chapter content
    index.adoc                   #   site landing page (Antora start_page; NOT in PDF)
    intro.adoc  recipes.adoc  hart.adoc  sbi.adoc  uefi.adoc  acpi.adoc
    smbios.adoc  contributors.adoc  bibliography.adoc
  partials/                      # single-use fragments, unedited heading levels
    acpi-id.adoc  acpi-prop.adoc  acpi-trace.adoc
  resources/brs.bib              # bibliography database
src/brs.adoc                     # BRS spec PDF assembler
src/brs-ts.adoc                  # BRS Test Specification PDF assembler (PDF-only)
Makefile                         # asciidoctor-pdf via Docker; ARC PDF naming
docs-resources/                  # submodule: PDF fonts/themes/logo
```

## Production model (important)

The canonical site is built **elsewhere**, by the central playbook at
`github.com/riscv-admin/antora.riscv.org`. This repo is just a **content
source** consumed by that playbook — registering it there (content-source
entry + `numbering_rules` entry) is a manual follow-up for a maintainer with
push access to that repo, not something this migration could do from here.

The central playbook supplies, uniformly to every spec:
- **Extensions**: `asciidoctor-kroki` (diagrams), `@djencks/asciidoctor-mathjax`
  (math), an ASAM extension for `cite:`/`bibliography::[]`, plus section/nav
  numbering extensions.
- **Shared AsciiDoc attributes**: `doctype: book`, `icons: font`, `xrefstyle`,
  `source-highlighter: highlight.js`, kroki config, math entities, etc.
- **UI**: `github.com/riscv-admin/riscv-antora-only-ui` release bundle.

Consequence — **keep `antora.yml` minimal** (name/title/version/nav plus the
spec-specific `asamBibliography`/`page-*` cover attributes). Component
attributes override the playbook, so setting rendering attributes here
(notably `sectnums`, which the central section-numbering extension controls)
would desync this spec from the rest of the library. Put preview-only
rendering config in `antora-playbook.yml` instead.

## Section numbering

Chapter/section numbering is applied by the **central playbook**, not this
repo — `nav.adoc`'s `numbering_rules` entry lives in the central playbook
repo, keyed by **line numbers** in `modules/ROOT/nav.adoc`. Editing this
repo's `nav.adoc` (adding/removing/reordering entries) without updating that
central entry silently desyncs site numbering. This registration is one of
the manual follow-ups flagged for a maintainer with push access to
`riscv-admin/antora.riscv.org`.

## Build commands

```bash
make build-brs VERSION_brs=vX.Y.Z DATE=YYYY-MM-DD      # BRS spec ARC PDF
make build-brs-ts VERSION_brs-ts=vX.Y.Z DATE=YYYY-MM-DD # BRS Test Spec ARC PDF
make stamp-antora VERSION_brs=vX.Y.Z DATE=YYYY-MM-DD   # stamp antora.yml to match the released BRS spec PDF

# Local Antora preview (BRS spec only; renders like production: diagrams + math):
npm install                   # one-time: Antora + kroki/mathjax extensions
docker compose up -d kroki    # local Kroki server on :9870 (for diagrams)
npm run preview               # antora --fetch antora-playbook.yml -> build/site/
docker compose down           # stop Kroki when done
```
