# Paleta y Tipografía oficial — CDMX Movilidad Integrada

Extracción del `ref/manual-mi-mb.pdf` (Manual de Identidad Movilidad Integrada). Esta es la fuente canónica para la app Parabús.

## Tipografías oficiales

Jerarquía documentada en el manual (sección Movilidad Integrada):

| # | Familia | Uso |
|---|---------|-----|
| 1 | **Tipo Movin CDMX** (marca registrada) | Primaria — display, headers, line names, numerales |
| 2 | **Source Sans Pro Bold** | Énfasis secundario |
| 3 | **Source Sans Pro Regular** | Body, UI |
| 4 | **Arial Narrow** | Fallback / compresión vertical |

**Mapeo en Parabús (iOS):**
- Tipo Movin CDMX → `BrandTypography.*` (acento de marca, display/numerales/line names)
- Source Sans Pro (cualquier weight) → **SF Pro** (system font de Apple, equivalente óptico)
- Arial Narrow → no aplica (no caso de uso en mobile)

**OTF disponibles en `Sources/Resources/Fonts/`:**
- `Tipo Movin CDMX Regular.otf` → PostScript: `TipoMovinCDMX-Regular`
- `Tipo Movin CDMX Bold.otf` → `TipoMovinCDMX-Bold`
- `Tipo Movin CDMX Light.otf` → `TipoMovinCDMX-Light`
- `Tipo Movin CDMX Italic.otf` → `TipoMovinCDMX-Italic`
- `Tipo Movin CDMX Bold Italic.otf` → `TipoMovinCDMX-BoldItalic`
- `Tipo Movin CDMX Light Italic.otf` → `TipoMovinCDMX-LightItalic`

## Paleta corporativa Metrobús

Color principal de la marca Metrobús — usado en logotipo y aplicaciones corporativas.

| Concepto | Pantone | sRGB Hex | RGB | CMYK |
|----------|---------|----------|-----|------|
| **Metrobús corporativo** | 186 C | `#C8102E` | 200, 16, 46 | C0 M100 Y80 K5 |

## Paleta de líneas Metrobús (OFICIAL)

⚠️ **Estos valores OFICIALES difieren significativamente de los hex anteriores en `UX_UI_CONTEXT.md` y `DesignTokens.swift`**. La fuente verdadera es el manual de marca; los hex previos eran aproximaciones.

| Línea | Pantone | sRGB Hex | RGB | CMYK | Discrepancia vs. anterior |
|-------|---------|----------|-----|------|---------------------------|
| **L1** | 1807 C | `#A4343A` | 164, 52, 58 | C3 M90 Y65 K28 | Antes: `D40D0D` (rojo brillante) → Oficial: rojo borgoña más oscuro |
| **L2** | 2602 C | `#87189D` | 135, 24, 157 | C58 M99 Y0 K0 | Antes: `7A2D8F` → Oficial: morado más saturado |
| **L3** | 377 C | `#7A9A01` | 122, 154, 1 | C41 M0 Y100 K22 | Antes: `218D21` (verde) → Oficial: olivo/amarillo-verde |
| **L4** | 021 C (Orange) | `#FE5000` | 254, 80, 0 | C0 M74 Y100 K0 | Antes: `F5A623` (oro/amarillo) → Oficial: **naranja puro** |
| **L5** | 2757 C | `#001E60` | 0, 30, 96 | C100 M81 Y0 K51 | Antes: `007AA6` (cyan) → Oficial: **azul navy profundo** |
| **L6** | Rhodamine Red C | `#E10098` | 225, 0, 152 | C5 M92 Y0 K0 | Antes: `CC0078` → Oficial: rosa rodamina más saturado |
| **L7** | 349 C | `#046A38` | 4, 106, 56 | C85 M3 Y91 K44 | Antes: `009966` (teal) → Oficial: **verde profundo** |

## Neutros (Pantone Cool Gray)

Para textos, íconos complementarios, fondos y separadores en mapas, planos y aplicaciones generales.

| Concepto | Pantone | sRGB Hex aprox | Uso documentado |
|----------|---------|----------------|-----------------|
| **Cool Gray 5 C** | Cool Gray 5 C | `#B1B3B3` | Aplicaciones generales, fondos |
| **Cool Gray 10 C** | Cool Gray 10 C | `#63666A` | "Textos e íconos complementarios en mapas de línea, mapas de barrio y mapas de ruta" (manual línea 240) |
| **Cool Gray 11 C** | Cool Gray 11 C | `#53565A` | Énfasis tipográfico, headers oscuros |
| **Process Black** | Process Black | `#231F20` | Texto principal sobre claro |

## Acentos secundarios documentados

Mencionados en la tabla de "Paleta de pantone" (línea 868 del extracto):
- **7420 C** (`#962037` aprox) — wine/burgundy corporativo
- **465 C** (`#BA9A5B` aprox) — tan/khaki secundario
- **424 C** (`#707372` aprox) — gris medio (alternativa a Cool Gray)
- **Black C** — negro absoluto

## Notas de implementación

- **Color space**: la app usa `Color(.displayP3, red:green:blue:)` en `DesignTokens.swift` para los colores de marca. Los hex aquí están en sRGB; la implementación los pasa al espacio Display-P3 sin reconvertir. Esto produce colores **ligeramente más saturados** en dispositivos compatibles (iPhone X y posteriores), lo cual es perceptible pero aceptable para identidad de marca digital.
- **Sistema multimodal extendido** (Metro, Cablebús, Trolebús, RTP, Tren Ligero, Suburbano): el manual incluye estas secciones pero los swatches de color están embebidos como imágenes que `pdftotext` no extrae. Extracción visual queda **diferida** — agregar cuando se introduzca UI de transferencias intermodales.
- **Equivalencias Pantone → sRGB para neutros**: derivadas de la tabla oficial Pantone Solid Coated en CSS Color Module / Adobe specs. Para máxima fidelidad en producción, validar contra material impreso oficial.

## Referencias

- `ref/manual-mi-mb.pdf` — Manual de Identidad Movilidad Integrada CDMX
- Extracto texto: `ref/manual-mi-mb.txt` (1473 líneas, generado con `pdftotext -layout`)
- Sección 3 Metrobús — líneas 132-218 del .txt (paleta Pantone)
- Sección final — línea 867-871 (jerarquía tipográfica)
