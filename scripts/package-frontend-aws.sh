#!/usr/bin/env bash
# Builds frontend/ and zips the static output (dist/) for AWS — either
# Amplify Hosting's manual "drag and drop a zip" deploy, or extraction to
# an S3 static-website bucket. The zip contains the CONTENTS of dist/ at
# its root (index.html at the top level), not source code — there's no
# build step on the AWS side for a static zip upload, so it must already
# be built.
#
# Usage: ./scripts/package-frontend-aws.sh [output-path]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
OUT_FILE="${1:-$ROOT_DIR/frontend-web.zip}"

if ! command -v zip >/dev/null 2>&1; then
  echo "Error: 'zip' is not installed. On Windows, use scripts/package-frontend-aws.ps1 instead." >&2
  exit 1
fi

if [ ! -f "$FRONTEND_DIR/.env.production" ]; then
  echo "Warning: frontend/.env.production not found." >&2
  echo "  VITE_API_BASE_URL and VITE_VAPID_PUBLIC_KEY are baked in at build time —" >&2
  echo "  without this file the build falls back to frontend/.env.example defaults" >&2
  echo "  (localhost), which will not work against a deployed backend." >&2
  echo "  Copy frontend/.env.example -> frontend/.env.production and fill in real values first." >&2
fi

cd "$FRONTEND_DIR"
npm ci
npm run build

rm -f "$OUT_FILE"
cd dist
zip -r -q "$OUT_FILE" .

echo "Created $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
echo "Deploy via: Amplify Console -> 'Deploy without Git provider' -> drag & drop this zip"
echo "        or: unzip and 'aws s3 sync . s3://<bucket>' for S3 static hosting"
