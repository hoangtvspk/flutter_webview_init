#!/bin/bash
set -e

ENVIRONMENT=${ENVIRONMENT:-dev}
ENV_FILE="lib/config/.env.$ENVIRONMENT"

mkdir -p lib/config

# Create the env file for current environment
cat > "$ENV_FILE" << EOF
BASE_URL=${BASE_URL:-}
API_KEY=${API_KEY:-}
EOF

# Create placeholder files for other environments (so pubspec.yaml doesn't fail)
for env in dev staging prod; do
  if [ "$env" != "$ENVIRONMENT" ]; then
    PLACEHOLDER_FILE="lib/config/.env.$env"
    if [ ! -f "$PLACEHOLDER_FILE" ]; then
      cat > "$PLACEHOLDER_FILE" << EOF
# Placeholder file for $env environment
# This file is created during build and will be overwritten if $env is the active environment
BASE_URL=
API_KEY=
EOF
    fi
  fi
done

echo "✅ Created $ENV_FILE"
