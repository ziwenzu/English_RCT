#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

texfile="${1:-draft.tex}"
base="${texfile%.tex}"

latexmk -pdf -interaction=nonstopmode -halt-on-error "$texfile"

# Keep the PDF, but clear local LaTeX intermediates after a successful build.
rm -f \
  "${base}.aux" \
  "${base}.bbl" \
  "${base}.bcf" \
  "${base}.blg" \
  "${base}.fdb_latexmk" \
  "${base}.fls" \
  "${base}.log" \
  "${base}.out" \
  "${base}.ptc" \
  "${base}.run.xml"
