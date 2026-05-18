# Station Pictograms

Vector pictograms for Metrobús CDMX station signage cenefas.

**Status: empty in PR1 (deferred).** The cenefa component (`StationSignage`)
renders gracefully without a pictogram — when no asset is bundled for a station,
the rightmost black block is simply omitted. This honors the spec's
"cobertura parcial OK por diseño" stance.

## Source

Pictograms are visible in the printed Metrobús manual at
`ref/manual-mi-mb.pdf`, distributed across pages 17-25+ in 6-7 colored rows
per page (one per line L1-L7 plus L0 Circuito). Page 25 was extracted as
SVG in commit `98b905a` (see `ref/pages/page-25.svg`) for future extraction
work. The extraction strategy decision was documented in `ref/UX_UI_CONTEXT.md`
under "⚡ Update 2026-05-18 — Pictogram extraction strategy".

## To add coverage

Naming convention: `pictogram-{stationId}.pdf` where `stationId` matches
`GTFSStation.id` in `Sources/Models/GTFSStations.swift`.

1. Identify the pictogram in `ref/pages/page-25.svg` (or rasterize another
   page of `ref/manual-mi-mb.pdf` with `pdftocairo -svg`).
2. Extract the pictogram as a single-page square PDF (Preview/Sketch/Inkscape
   crop+export, or scripted clipPath-based extraction).
3. Save as `Sources/Resources/Pictograms/pictogram-{stationId}.pdf` (single-page,
   square aspect; ~24-60pt rendered size).
4. The lookup in `Sources/Models/StationPictogram.swift` finds the asset
   automatically via `Bundle.module` — no code change needed.

## Why no extraction in PR1

T2 analysis (2026-05-18) found that page-25.svg contains only ~53 pictogram
boxes (one line's worth, roughly), not the full 250+. Building a robust
extraction pipeline would require parsing all 6-7 line pages and bootstrapping
a coordinate→stationId mapping per page from GTFS stop order. That's its own
multi-task scope, separate from this PR's visual feature.

The cenefa visual identity (MI · MB · line-color name band · line number)
carries the brand language without the pictogram. Future incremental backfill
just adds polish.
