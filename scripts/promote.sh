#!/bin/bash
set -e

# Skrypt promujący serwis między środowiskami
# Użycie: ./scripts/promote.sh <serwis> <źródło> <cel>

SERVICE_NAME=$1
FROM_ENV=$2
TO_ENV=$3

if [ -z "$SERVICE_NAME" ] || [ -z "$FROM_ENV" ] || [ -z "$TO_ENV" ]; then
  echo "❌ Błąd: Brakujące argumenty"
  echo "Użycie: ./scripts/promote.sh <serwis> <źródło> <cel>"
  echo "Przykład: ./scripts/promote.sh greeting-service dev staging"
  echo ""
  echo "Środowiska: dev, staging, pre, prod"
  exit 1
fi

# Walidacja
if [ ! -d "apps/$SERVICE_NAME" ]; then
  echo "❌ Błąd: Serwis 'apps/$SERVICE_NAME' nie istnieje"
  exit 1
fi

FROM_FILE="apps/$SERVICE_NAME/values-$FROM_ENV.yaml"
TO_FILE="apps/$SERVICE_NAME/values-$TO_ENV.yaml"

if [ ! -f "$FROM_FILE" ]; then
  echo "❌ Błąd: Plik '$FROM_FILE' nie istnieje"
  exit 1
fi

if [ ! -f "$TO_FILE" ]; then
  echo "❌ Błąd: Plik '$TO_FILE' nie istnieje"
  exit 1
fi

# Sprawdź czy yq jest zainstalowany
if ! command -v yq &> /dev/null; then
  echo "❌ Błąd: yq nie jest zainstalowany"
  echo "Instalacja:"
  echo "  macOS: brew install yq"
  echo "  Linux: https://github.com/mikefarah/yq#install"
  exit 1
fi

echo "🚀 Promocja: $SERVICE_NAME ($FROM_ENV → $TO_ENV)"
echo ""

# Pobierz aktualny tag ze źródła
TAG=$(yq eval '.java-service.image.tag' "$FROM_FILE")
echo "📦 Tag w $FROM_ENV: $TAG"

# Sprawdź aktualny tag w celu
CURRENT_TAG=$(yq eval '.java-service.image.tag' "$TO_FILE")
echo "📦 Tag w $TO_ENV (aktualnie): $CURRENT_TAG"

if [ "$TAG" == "$CURRENT_TAG" ]; then
  echo "ℹ️  Tagi są identyczne - brak zmian"
  exit 0
fi

echo ""
echo "⚠️  Czy chcesz promować $TAG do $TO_ENV? (y/n)"
read -r CONFIRM

if [ "$CONFIRM" != "y" ]; then
  echo "❌ Anulowano"
  exit 0
fi

# Utwórz branch
BRANCH="promote-$SERVICE_NAME-$TO_ENV-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH"

# Zaktualizuj tag
yq eval -i ".java-service.image.tag = \"$TAG\"" "$TO_FILE"

echo ""
echo "✅ Zaktualizowano $TO_FILE:"
echo "   Tag: $CURRENT_TAG → $TAG"

# Commit
git add "$TO_FILE"
git commit -m "promote: $SERVICE_NAME from $FROM_ENV to $TO_ENV - $TAG"

echo ""
echo "📤 Push do remote..."
git push origin "$BRANCH"

echo ""
echo "✅ Branch '$BRANCH' został utworzony i wypushowany"
echo ""
echo "📝 Następne kroki:"
echo "1. Otwórz PR na GitHubie:"
echo "   https://github.com/funmagsoft/gitops/compare/$BRANCH"
echo ""
echo "2. Review i merge PR"
echo ""
echo "3. Po merge: automatyczny deploy do '$TO_ENV'"
echo ""
echo "Lub użyj GitHub CLI:"
echo "  gh pr create --title \"Promote $SERVICE_NAME to $TO_ENV\" \\"
echo "    --body \"Promote $SERVICE_NAME from $FROM_ENV to $TO_ENV (tag: $TAG)\""

