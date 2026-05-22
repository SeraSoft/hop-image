#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-serasoft/hop}"
HOP_REPO="${HOP_REPO:-https://github.com/SeraSoft/hop.git}"

# ---------------------------------------------------------------------------
# Version selection
# ---------------------------------------------------------------------------
if [[ -n "${HOP_VERSION:-}" ]]; then
  echo "📌 Using specified version: ${HOP_VERSION}"
else
  echo "🔍 Fetching available stable releases from GitHub..."

  TAGS_JSON=$(curl -sf "https://api.github.com/repos/SeraSoft/hop/git/refs/tags" || true)

  if [[ -z "$TAGS_JSON" ]]; then
    echo "⚠️  Could not fetch tags. Set HOP_VERSION manually:"
    echo "   HOP_VERSION=2.16.2 ./build.sh"
    exit 1
  fi

  # Extract tags matching X.Y.Z only (no -rc, -RC, -beta, etc.)
  mapfile -t STABLE_TAGS < <(
    echo "$TAGS_JSON" \
      | grep '"ref":' \
      | sed 's|.*refs/tags/||;s|".*||' \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -V -r
  )

  if [[ ${#STABLE_TAGS[@]} -eq 0 ]]; then
    echo "⚠️  No stable tags found. Set HOP_VERSION manually:"
    echo "   HOP_VERSION=2.16.2 ./build.sh"
    exit 1
  fi

  echo ""
  echo "Available stable releases:"
  for i in "${!STABLE_TAGS[@]}"; do
    printf "  [%d] %s\n" "$((i + 1))" "${STABLE_TAGS[$i]}"
  done
  echo ""
  read -rp "Select a release [1]: " CHOICE
  CHOICE="${CHOICE:-1}"

  if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#STABLE_TAGS[@]} )); then
    echo "Invalid choice."
    exit 1
  fi

  HOP_VERSION="${STABLE_TAGS[$((CHOICE - 1))]}"
  echo "✅ Selected: ${HOP_VERSION}"
fi

HOP_BRANCH="${HOP_BRANCH:-${HOP_VERSION}}"

echo ""
echo "🔨 Building ${IMAGE_NAME}:${HOP_VERSION} from branch/tag '${HOP_BRANCH}'..."

DOCKER_BUILDKIT=1 docker build \
  --build-arg HOP_REPO="${HOP_REPO}" \
  --build-arg HOP_BRANCH="${HOP_BRANCH}" \
  --build-arg HOP_VERSION="${HOP_VERSION}" \
  -t "${IMAGE_NAME}:${HOP_VERSION}" \
  -t "${IMAGE_NAME}:latest" \
  -f Dockerfile \
  .

echo ""
echo "✅ Build complete: ${IMAGE_NAME}:${HOP_VERSION}"
echo ""
echo "To verify the image:"
echo "  docker run --rm --entrypoint /bin/bash ${IMAGE_NAME}:${HOP_VERSION} -c \"/opt/hop/hop-run.sh --version\""
