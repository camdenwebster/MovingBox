#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="$ROOT_DIR/Packages"

if [ ! -d "$PACKAGES_DIR" ]; then
  echo "No Packages directory found at $PACKAGES_DIR"
  exit 1
fi

found_any=false

for manifest in "$PACKAGES_DIR"/*/Package.swift; do
  if [ ! -f "$manifest" ]; then
    continue
  fi

  found_any=true
  package_dir="$(dirname "$manifest")"

  echo "============================================================"
  echo "Running Swift package tests in: $package_dir"
  echo "============================================================"

  (
    cd "$package_dir"
    swift test --parallel
  )

done

if [ "$found_any" = false ]; then
  echo "No local packages found under $PACKAGES_DIR"
  exit 1
fi
