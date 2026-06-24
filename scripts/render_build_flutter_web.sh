#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_GIT_REF="${FLUTTER_GIT_REF:-stable}"
FLUTTER_HOME="${FLUTTER_HOME:-$ROOT_DIR/.render/flutter}"
API_BASE_URL="${API_BASE_URL:-https://student-job-platform-api.onrender.com}"

if [ ! -d "$FLUTTER_HOME/.git" ]; then
  rm -rf "$FLUTTER_HOME"
  git clone --depth 1 --branch "$FLUTTER_GIT_REF" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
else
  git -C "$FLUTTER_HOME" fetch --depth 1 origin "$FLUTTER_GIT_REF"
  git -C "$FLUTTER_HOME" checkout FETCH_HEAD
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter config --enable-web
flutter --version

cd "$ROOT_DIR/student_app"
flutter pub get
flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL="$API_BASE_URL"
