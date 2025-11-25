#!/bin/bash

# Skrypt wyświetlający status deploymentów
# Użycie: ./scripts/status.sh [nazwa-serwisu]

SERVICE_NAME=$1

# Sprawdź czy yq jest zainstalowany
if ! command -v yq &> /dev/null; then
  echo "❌ Błąd: yq nie jest zainstalowany"
  echo "Instalacja:"
  echo "  macOS: brew install yq"
  echo "  Linux: https://github.com/mikefarah/yq#install"
  exit 1
fi

echo "📊 Status deploymentów GitOps"
echo ""

if [ -n "$SERVICE_NAME" ]; then
  # Status dla konkretnego serwisu
  if [ ! -d "apps/$SERVICE_NAME" ]; then
    echo "❌ Błąd: Serwis 'apps/$SERVICE_NAME' nie istnieje"
    exit 1
  fi
  
  echo "🔍 Serwis: $SERVICE_NAME"
  echo ""
  
  for ENV in dev staging pre prod; do
    FILE="apps/$SERVICE_NAME/values-$ENV.yaml"
    if [ -f "$FILE" ]; then
      TAG=$(yq eval '.java-service.image.tag' "$FILE")
      REPLICAS=$(yq eval '.java-service.replicaCount' "$FILE")
      printf "  %-10s | Tag: %-20s | Replicas: %s\n" "$ENV" "$TAG" "$REPLICAS"
    fi
  done
  
  echo ""
  echo "📜 Ostatnie 5 deployów do dev:"
  git log --oneline -5 "apps/$SERVICE_NAME/values-dev.yaml"
  
else
  # Status dla wszystkich serwisów
  echo "📦 Wszystkie serwisy:"
  echo ""
  
  for SERVICE_DIR in apps/*/; do
    SERVICE=$(basename "$SERVICE_DIR")
    if [ -f "apps/$SERVICE/values-dev.yaml" ]; then
      TAG_DEV=$(yq eval '.java-service.image.tag' "apps/$SERVICE/values-dev.yaml")
      TAG_PROD=$(yq eval '.java-service.image.tag' "apps/$SERVICE/values-prod.yaml")
      printf "  %-25s | Dev: %-15s | Prod: %-15s\n" "$SERVICE" "$TAG_DEV" "$TAG_PROD"
    fi
  done
fi

echo ""

