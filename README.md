# GitOps Repository

Centralne repozytorium konfiguracji dla wszystkich serwisów wdrażanych na AKS.

## Struktura

```
gitops/
├── .github/workflows/
│   ├── deploy.yml          # Główny workflow CD (deploy do AKS)
│   └── README.md           # Dokumentacja workflow
├── apps/
│   └── greeting-service/   # Przykładowy serwis
│       ├── Chart.yaml      # Helm chart z dependency na java-service
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       ├── values-pre.yaml
│       ├── values-prod.yaml
│       └── README.md
└── README.md               # Ten plik
```

## Zasada działania

### 1. CI (w repo serwisu)
```
Push do main → build + test + push ACR → trigger GitOps
```

### 2. CD (w tym repo)
```
Workflow deploy.yml:
  1. Update values-{env}.yaml (zmiana image tag)
  2. Commit do gitops repo (audit trail)
  3. Helm upgrade --install na AKS
```

### 3. Audit Trail
```bash
# Historia deployów do dev
git log apps/greeting-service/values-dev.yaml

# Historia deployów do prod
git log apps/greeting-service/values-prod.yaml
```

## Dodawanie nowego serwisu

### Automatycznie (w przyszłości):
```bash
./scripts/add-service.sh my-new-service
```

### Ręcznie:
```bash
mkdir -p apps/my-new-service

# Skopiuj Chart.yaml z innego serwisu
cp apps/greeting-service/Chart.yaml apps/my-new-service/
# Edytuj name w Chart.yaml

# Utwórz values dla wszystkich środowisk
for env in dev staging pre prod; do
  cat > apps/my-new-service/values-$env.yaml <<EOF
java-service:
  replicaCount: 1
  fullnameOverride: "my-new-service"
  image:
    repository: ""
    tag: "latest"
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
done

# Dostosuj resources/replicas per środowisko
# Commit
git add apps/my-new-service/
git commit -m "feat(apps): add my-new-service config"
git push
```

## Deployment

### Automatyczny (DEV)
Każdy push do `main` w serwisie automatycznie deployuje do `dev`.

### Ręczny (STAGING/PRE/PROD)

#### Opcja 1: GitHub UI
```
Actions → Deploy to AKS → Run workflow:
  - app_name: greeting-service
  - environment: staging
  - image_tag: abc1234
```

#### Opcja 2: Pull Request (zalecane dla prod)
```bash
# 1. Sprawdź aktualny tag w dev/staging
TAG=$(yq eval '.java-service.image.tag' apps/greeting-service/values-dev.yaml)

# 2. Utwórz branch i zaktualizuj prod
git checkout -b promote-greeting-prod
yq eval -i ".java-service.image.tag = \"$TAG\"" apps/greeting-service/values-prod.yaml
git add apps/greeting-service/values-prod.yaml
git commit -m "promote: greeting-service to prod - $TAG"
git push origin promote-greeting-prod

# 3. Otwórz PR → Review (ops team) → Approve → Merge → Auto-deploy
```

## Rollback

```bash
# 1. Znajdź poprzednią wersję
git log --oneline apps/greeting-service/values-prod.yaml

# 2. Revert do poprzedniej wersji
git revert <commit-sha>
git push origin main

# 3. Opcjonalnie: ręcznie trigger deploy
# (lub poczekaj na auto-trigger jeśli masz Argo CD)
```

## Secrets i Variables

### Wymagane w repo gitops

**Secrets** (Settings → Secrets and variables → Actions):
- `AZURE_CLIENT_ID` - Azure SP Client ID (OIDC)
- `AZURE_TENANT_ID` - Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID
- `AKS_RG` - Resource Group dla AKS
- `AKS_NAME` - Nazwa klastra AKS

**Variables**:
- `ACR_LOGIN_SERVER` - np. `myacr.azurecr.io`

## Environments (Protection Rules)

Skonfiguruj w: Settings → Environments

| Environment | Reviewers | Description |
|-------------|-----------|-------------|
| `dev` | None (auto-approve) | Development |
| `staging` | Team leads (opcjonalnie) | Pre-production testing |
| `pre` | Team leads + ops | Final validation |
| `prod` | **Ops team (wymagane!)** | Production |

## Dokumentacja

- [Workflow deploy.yml](.github/workflows/README.md) - szczegóły workflow CD
- [greeting-service](apps/greeting-service/README.md) - przykład konfiguracji serwisu

## FAQ

### Jak sprawdzić, co jest wdrożone w prod?
```bash
yq eval '.java-service.image.tag' apps/greeting-service/values-prod.yaml
```

### Jak wdrożyć ten sam tag do wielu środowisk?
```bash
TAG=abc1234
for env in staging pre prod; do
  yq eval -i ".java-service.image.tag = \"$TAG\"" apps/greeting-service/values-$env.yaml
done
git commit -am "deploy: greeting-service to staging+pre+prod - $TAG"
git push
```

### Deployment failuje - jak debugować?
```bash
# 1. Sprawdź workflow w GitHub Actions
# 2. Sprawdź logi w AKS:
kubectl logs -n prod deployment/greeting-service

# 3. Sprawdź events:
kubectl get events -n prod --sort-by='.lastTimestamp'

# 4. Sprawdź czy image istnieje:
az acr repository show-tags --name myacr --repository greeting-service
```

### Czy mogę wdrożyć bez commitowania do gitops?
**Nie zalecane** - ale możliwe przez `helm` bezpośrednio:
```bash
helm upgrade --install greeting-service apps/greeting-service \
  -n prod \
  --set java-service.image.tag=abc1234
```
⚠️ **Uwaga**: To ominięcie GitOps - brak audit trail!

## Kontakt

W razie problemów:
- Sprawdź [Troubleshooting](.github/workflows/README.md#troubleshooting)
- Otwórz issue w tym repo
- Skontaktuj się z zespołem Platform/Ops
