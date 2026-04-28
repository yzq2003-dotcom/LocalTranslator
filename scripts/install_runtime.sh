#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$HOME/Library/Application Support/LocalTranslator"

mkdir -p "$RUNTIME_DIR"

if [[ ! -x "$PROJECT_DIR/TranslatorUI" ]]; then
  swiftc "$PROJECT_DIR/TranslatorUI.swift" -o "$PROJECT_DIR/TranslatorUI"
fi

cp "$PROJECT_DIR/translate.py" "$RUNTIME_DIR/translate.py"
cp "$PROJECT_DIR/TranslatorUI" "$RUNTIME_DIR/TranslatorUI"
chmod +x "$RUNTIME_DIR/translate.py" "$RUNTIME_DIR/TranslatorUI"

echo "Installed LocalTranslator runtime to: $RUNTIME_DIR"
