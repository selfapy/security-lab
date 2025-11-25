#!/usr/bin/env bash
set -euo pipefail

# Determine absolute path to the script, even if symlinked
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default list: next to the script
DEFAULT_AFFECTED_LIST="$SCRIPT_DIR/shai-hulud-packages.txt"

# User can override by passing a path as first argument
if [[ $# -ge 1 ]]; then
  AFFECTED_LIST="$(realpath "$1")"
else
  AFFECTED_LIST="$DEFAULT_AFFECTED_LIST"
fi

ROOT_DIR="$(pwd)"
REPORT_FILE="$ROOT_DIR/shai-hulud-audit-report.txt"

# Validate the list file
if [[ ! -f "$AFFECTED_LIST" ]]; then
  echo "❌ Affected packages list not found: $AFFECTED_LIST"
  echo "Expected default location: $DEFAULT_AFFECTED_LIST"
  exit 1
fi

echo "🔍 Running Shai-Hulud supply chain audit across repository"
echo "🔍 Using affected package list: $AFFECTED_LIST"
echo "Output → $REPORT_FILE"
echo "" > "$REPORT_FILE"

# Pick correct package manager
detect_pm() {
  if command -v pnpm &>/dev/null && [[ -f pnpm-lock.yaml ]]; then
    echo "pnpm"
  elif command -v yarn &>/dev/null && [[ -f yarn.lock ]]; then
    echo "yarn"
  elif command -v npm &>/dev/null; then
    echo "npm"
  else
    echo ""
  fi
}

scan_directory() {
  local dir="$1"
  local pm

  echo ""
  echo "📁 Checking: $dir"
  echo "" >> "$REPORT_FILE"
  echo "=== Directory: $dir ===" >> "$REPORT_FILE"

  pm=$(detect_pm)

  if [[ -z "$pm" ]]; then
    echo "⚠️  No supported package manager detected in $dir"
    return
  fi

  echo "→ Using package manager: $pm"

  # Install dependency tree offline if possible
  if [[ "$pm" == "npm" ]]; then
    npm ls --all --json > deps.json 2>/dev/null || true
  elif [[ "$pm" == "yarn" ]]; then
    yarn list --json > deps.json 2>/dev/null || true
  elif [[ "$pm" == "pnpm" ]]; then
    pnpm list --json --depth Infinity > deps.json 2>/dev/null || true
  fi

  if [[ ! -f deps.json ]]; then
    echo "⚠️  Could not generate dependency tree"
    return
  fi

  echo "→ Checking dependencies for compromised packages…"

  # Iterate each affected package
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue

    matches=$(grep -i "\"$pkg\"" deps.json || true)

    if [[ -n "$matches" ]]; then
      echo -e "${RED}❌ Found affected package: $pkg${RESET}"
      echo "Affected package: $pkg" >> "$REPORT_FILE"
      grep -iC2 "\"$pkg\"" deps.json >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    fi
  done < "$AFFECTED_LIST"

  rm -f deps.json
}

export -f scan_directory detect_pm

# Find all directories containing package.json
echo "📦 Searching for Node projects…"
mapfile -t dirs < <(find . -type f -name "package.json" -not -path "*/node_modules/*" -exec dirname {} \;)

for d in "${dirs[@]}"; do
  (cd "$d" && scan_directory "$d")
done

echo ""
echo "🟢 Scan complete. Full report saved to: $REPORT_FILE"
echo "If no ❌ entries appeared, you're likely unaffected."

