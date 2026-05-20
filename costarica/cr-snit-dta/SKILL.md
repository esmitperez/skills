---
name: cr-snit-dta
description: Fetch the latest Costa Rica División Territorial Administrativa (DTA) from SNIT (https://www.snitcr.go.cr/biblioteca_DTA), convert the official PDF to text, and parse it into cantones.csv and distritos.csv. Use when the user asks for Costa Rica districts/cantones/distritos/provinces, refreshing CR territorial data, the latest DTA, SNIT documents, or "División Territorial Administrativa".
---

# Costa Rica DTA — latest territorial division

Pulls the most recent **División Territorial Administrativa** PDF that SNIT publishes under *Documentación General*, converts it to UTF-8 text with `pdftotext`, and parses canton/district codes into CSVs.

All paths below are relative to this skill directory (`costarica/cr-snit-dta/` in this repo, or wherever you've copied the folder).

## Prerequisites

These must be on `PATH`:

- `bash`, `curl`, `python3` (stdlib only — used for URL encoding + JSON filtering)
- `pdftotext` (from `poppler` / `poppler-utils`). On macOS: `brew install poppler`. On Debian/Ubuntu: `apt-get install -y poppler-utils`.

## Run

One command does everything:

```bash
./fetch_dta.sh
```

It:

1. POSTs to `https://www.snitcr.go.cr/consultar_DTA_documentos_generales` (the JSON API behind the *Documentación General* table — the public page is JS-rendered, so we hit the backing endpoint directly with curl).
2. Filters rows whose title starts with `División Territorial Administrativa` and picks the row with the highest `anio`.
3. URL-encodes the document path (the PDF filenames contain spaces and parentheses), downloads the PDF to `cache/<year>/dta-<year>.pdf`.
4. Converts to text with `pdftotext -layout -enc UTF-8` → `cache/<year>/dta-<year>.txt`.
5. Runs `parse.sh` → `cache/<year>/parsed/{cantones,distritos}.csv`.

Re-running is idempotent: PDF and TXT are reused unless `--force` is passed.

### Flags

```text
./fetch_dta.sh                 # latest year, idempotent
./fetch_dta.sh --year 2023     # specific year (see --list for what's available)
./fetch_dta.sh --force         # re-download + re-convert + re-parse
./fetch_dta.sh --list          # print every DTA year SNIT publishes (to stderr)
./fetch_dta.sh --no-parse      # stop after .txt, skip parse.sh
```

### Outputs

```text
cache/
  index.json                          # raw API response (all 21 DTA rows)
  <year>/
    dta-<year>.pdf                    # raw PDF from SNIT
    dta-<year>.txt                    # pdftotext -layout output
    parsed/
      cantones.csv                    # prov_id,canton_id,name
      distritos.csv                   # prov_id,canton_id,dist_id,codigo,name
```

For the 2025 DTA you should see **84 cantones** and **~479 distritos** (plus header rows).

## Customizing the parser

`parse.sh` is the user-supplied parsing logic. It's called with this contract:

```bash
parse.sh <txt-path> <out-dir> <year>
```

The driver creates `<out-dir>` before invoking. Edit `parse.sh` freely — add more output files, change the grammar, etc. The current version produces `cantones.csv` and `distritos.csv`.

## Gotchas

- **The biblioteca page is JS-rendered.** A naive `curl` of `https://www.snitcr.go.cr/biblioteca_DTA` returns an empty HTML shell. The data comes from a POST to `/consultar_DTA_documentos_generales` (form-encoded body: `anio=TODOS&tipo_documento=TODOS`). That's the endpoint `fetch_dta.sh` calls.
- **DTA filenames contain spaces and parentheses.** The 2025 file is `DE 44882-MGP Declaratoria Oficial DTA (Alcance 12 Gaceta 17 del 28 01 2025).pdf`. The driver URL-encodes the path component before downloading; plain `curl` against the raw URL fails with `Malformed input to a URL function`.
- **The 2025 PDF lives on a different host than older PDFs.** 2023 and 2025 are served from `www.snitcr.go.cr/fe/http/Home/public/pdfs/leyes/`; everything 2021 and earlier is on `files.snitcr.go.cr/documentacion_general_dta/`. The driver doesn't hard-code the host — it uses the `url` field from the API response.
- **`pdftotext` output quality varies by year.** The 2025 PDF extracts cleanly; the 2023 PDF uses a font embedding without a proper ToUnicode CMap, so much of the body text comes out as gibberish (e.g. `0120324367801090240367` instead of legible Spanish). `parse.sh` returns 0 cantones/distritos on that file. If you need to parse pre-2023 reliably, you'd need to add an OCR fallback (e.g. `pdftoppm` → `tesseract -l spa`). The current skill targets the **latest** DTA, which works.
- **The skill is not frozen during election years.** SNIT freezes the DTA *publication* 14 months before a presidential/municipal election, but the API still returns the previously published document. `--list` always reflects what's currently available.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `curl: (3) URL rejected: Malformed input to a URL function` | Tried to download the raw URL with spaces | The driver handles this; if you replicated the curl manually, URL-encode the path |
| `==> downloading PDF -> ...` then `curl: (22) ... 404` | Spaces in URL leaked through shell word-splitting | Already fixed; the driver tab-separates the year/url/fecha. If you customize it, watch for this |
| `missing required tool: pdftotext` | poppler not installed | `brew install poppler` (macOS) or `apt-get install -y poppler-utils` |
| `parse.sh not present (or not executable); skipping parse step` | `parse.sh` missing or chmod 644 | `chmod +x parse.sh` |
| Parser produces 0 rows | Source PDF text is garbled (see Gotchas re: 2023) | Use a year that extracts cleanly, or add OCR |

## Files

- [fetch_dta.sh](fetch_dta.sh) — orchestrator (network + URL-encode + pdftotext + dispatch to parse.sh)
- [parse.sh](parse.sh) — CSV extraction
- [cache/](cache/) — outputs (gitignore as appropriate)
