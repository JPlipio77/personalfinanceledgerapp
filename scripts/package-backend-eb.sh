#!/usr/bin/env bash
# Packages backend/ as a standalone zip for Elastic Beanstalk "Upload and
# deploy" (console) or `eb deploy --staged`.
#
# Important: this zips backend/ in isolation, NOT the repo root. The repo
# root's package.json declares npm workspaces (backend + frontend); if you
# zip the monorepo root instead, EB's `npm install` will try to resolve it
# as a workspace and fail or silently produce a broken install.
#
# Usage: ./scripts/package-backend-eb.sh [output-path]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
OUT_FILE="${1:-$ROOT_DIR/backend-eb.zip}"

if ! command -v zip >/dev/null 2>&1; then
  echo "Error: 'zip' is not installed. On Windows, use scripts/package-backend-eb.ps1 instead." >&2
  exit 1
fi

if [ ! -f "$BACKEND_DIR/package-lock.json" ]; then
  echo "Error: backend/package-lock.json is missing. Generate it before packaging" \
       "(see README) — EB builds are not reproducible without it." >&2
  exit 1
fi

rm -f "$OUT_FILE"

cd "$BACKEND_DIR"
zip -r -q "$OUT_FILE" . \
  -x "node_modules/*" \
  -x ".env" \
  -x ".env.*" \
  -x "coverage/*" \
  -x "tests/*" \
  -x ".git/*" \
  -x "*.log" \
  -x "*.md" \
  -x "jest.config.js" \
  -x ".eslintrc.js" \
  -x "scripts/*"

echo "Created $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
echo "Deploy via: EB console 'Upload and deploy', or: eb deploy --staged"
