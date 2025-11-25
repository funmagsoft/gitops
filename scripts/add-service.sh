#!/bin/bash
set -e

# Skrypt dodający nowy serwis do GitOps
# Użycie: ./scripts/add-service.sh <nazwa-serwisu>

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "❌ Błąd: Podaj nazwę serwisu"
  echo "Użycie: ./scripts/add-service.sh <nazwa-serwisu>"
  echo "Przykład: ./scripts/add-service.sh payment-service"
  exit 1
fi

if [ -d "apps/$SERVICE_NAME" ]; then
  echo "❌ Błąd: Serwis 'apps/$SERVICE_NAME' już istnieje"
  exit 1
fi

echo "📦 Tworzę konfigurację GitOps dla: $SERVICE_NAME"
echo ""

# Utwórz katalog
mkdir -p "apps/$SERVICE_NAME"

# Chart.yaml
cat > "apps/$SERVICE_NAME/Chart.yaml" <<EOF
apiVersion: v2
name: $SERVICE_NAME
description: Helm chart for $SERVICE_NAME using shared java-service chart
type: application
version: 0.1.0

dependencies:
  - name: java-service
    version: 1.0.0
    repository: "https://funmagsoft.github.io/helm/charts"
EOF

# values-dev.yaml
cat > "apps/$SERVICE_NAME/values-dev.yaml" <<EOF
java-service:
  replicaCount: 1
  fullnameOverride: "$SERVICE_NAME"
  image:
    repository: ""      # Będzie ustawiane przez workflow
    tag: "latest"       # Placeholder - będzie nadpisywane
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
EOF

# values-staging.yaml
cat > "apps/$SERVICE_NAME/values-staging.yaml" <<EOF
java-service:
  replicaCount: 2
  fullnameOverride: "$SERVICE_NAME"
  image:
    repository: ""
    tag: "latest"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
EOF

# values-pre.yaml
cat > "apps/$SERVICE_NAME/values-pre.yaml" <<EOF
java-service:
  replicaCount: 2
  fullnameOverride: "$SERVICE_NAME"
  image:
    repository: ""
    tag: "latest"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
EOF

# values-prod.yaml
cat > "apps/$SERVICE_NAME/values-prod.yaml" <<EOF
java-service:
  replicaCount: 5
  fullnameOverride: "$SERVICE_NAME"
  image:
    repository: ""
    tag: "latest"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "2000m"
EOF

# README.md
cat > "apps/$SERVICE_NAME/README.md" <<EOF
# $SERVICE_NAME - GitOps Configuration

Konfiguracja Helm dla $SERVICE_NAME we wszystkich środowiskach.

Szczegóły analogiczne do innych serwisów - zobacz \`../greeting-service/README.md\`

## Różnice między środowiskami

| Parametr | DEV | STAGING | PRE | PROD |
|----------|-----|---------|-----|------|
| **Replicas** | 1 | 2 | 2 | 5 |
| **Memory Request** | 256Mi | 512Mi | 512Mi | 1Gi |
| **Memory Limit** | 512Mi | 1Gi | 1Gi | 2Gi |
| **CPU Request** | 100m | 200m | 200m | 500m |
| **CPU Limit** | 500m | 1000m | 1000m | 2000m |
EOF

echo "✅ Utworzono: apps/$SERVICE_NAME/"
echo ""
echo "📄 Pliki:"
ls -1 "apps/$SERVICE_NAME/"
echo ""
echo "📝 Następne kroki:"
echo ""
echo "1. Zweryfikuj i dostosuj konfigurację (resources, replicas):"
echo "   vi apps/$SERVICE_NAME/values-*.yaml"
echo ""
echo "2. Commit i push do gitops:"
echo "   git add apps/$SERVICE_NAME/"
echo "   git commit -m \"feat(apps): add $SERVICE_NAME config\""
echo "   git push origin main"
echo ""
echo "3. Zmodyfikuj workflow w serwisie (w repo $SERVICE_NAME):"
echo "   Skopiuj .github/workflows/cicd.yml z greeting-service"
echo "   Zmień 'app_name: $SERVICE_NAME'"
echo ""
echo "4. Dodaj secrets w serwisie:"
echo "   - GITOPS_PAT"
echo "   - AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
echo ""
echo "5. Dodaj variables:"
echo "   - ACR_LOGIN_SERVER"
echo ""
echo "6. Test:"
echo "   git commit --allow-empty -m 'test: GitOps'"
echo "   git push origin main"
echo ""
echo "Szczegóły: gitops/README.md#-dodawanie-nowego-serwisu"

