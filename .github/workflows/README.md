# GitOps Workflows

## deploy.yml - Deployment do AKS

Główny workflow CD, który wdraża serwisy do AKS na podstawie zmian w `apps/`.

### Triggery

#### 1. `repository_dispatch` (automatyczny - z CI serwisów)
Wywoływany przez workflow CI w repo serwisów (greeting-service, hello-service).

**Payload**:
```json
{
  "app_name": "greeting-service",
  "environment": "dev",
  "image_tag": "abc1234",
  "acr_server": "myacr.azurecr.io"
}
```

**Przykład wywołania** (z greeting-service CI):
```yaml
- uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.GITOPS_PAT }}
    repository: funmagsoft/gitops
    event-type: deploy
    client-payload: |
      {
        "app_name": "greeting-service",
        "environment": "dev",
        "image_tag": "${{ needs.build.outputs.image_tag }}",
        "acr_server": "${{ vars.ACR_LOGIN_SERVER }}"
      }
```

#### 2. `workflow_dispatch` (ręczny - przez GitHub UI lub API)
Zespół ops może ręcznie wywołać deployment.

**Inputs**:
- `app_name` (string) - nazwa serwisu (np. `greeting-service`)
- `environment` (choice) - środowisko: `dev`, `staging`, `pre`, `prod`
- `image_tag` (string) - tag obrazu (SHA lub wersja)

### Flow

```
1. Parse inputs (repository_dispatch vs workflow_dispatch)
   ↓
2. Validate app exists w gitops repo
   ↓
3. Install yq (YAML processor)
   ↓
4. Update values-{env}.yaml:
   - java-service.image.repository = ACR_SERVER/APP_NAME
   - java-service.image.tag = IMAGE_TAG
   ↓
5. Commit changes to gitops repo (git log = audit trail)
   ↓
6. Azure Login (OIDC)
   ↓
7. AKS login
   ↓
8. Helm upgrade --install
   - namespace: {environment}
   - values file: values-{environment}.yaml
   - wait + timeout 5m
   ↓
9. Deployment Summary
```

### Secrets wymagane

W repo `gitops` → Settings → Secrets:

| Secret | Opis |
|--------|------|
| `AZURE_CLIENT_ID` | Azure Service Principal Client ID (OIDC) |
| `AZURE_TENANT_ID` | Azure Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |
| `AKS_RG` | Resource Group dla AKS |
| `AKS_NAME` | Nazwa klastra AKS |

### Variables wymagane

W repo `gitops` → Settings → Variables:

| Variable | Opis | Używane w |
|----------|------|-----------|
| `ACR_LOGIN_SERVER` | ACR login server (np. `myacr.azurecr.io`) | workflow_dispatch (fallback) |

### Permissions

```yaml
permissions:
  id-token: write   # OIDC do Azure
  contents: write   # Commitowanie zmian do gitops repo
```

### GitHub Environments (opcjonalne, zalecane)

Skonfiguruj w: Settings → Environments

#### dev
- Auto-approve (brak protection rules)

#### staging
- Reviewers: team-leads (opcjonalnie)

#### pre
- Reviewers: team-leads + ops

#### prod
- **Required reviewers**: ops-team (wymagane!)
- Deployment branches: tylko `main`

### Przykłady użycia

#### Automatyczny deploy do dev (z CI)
```
Push do main w greeting-service
  → CI workflow
  → Build + test + push ACR
  → repository_dispatch do gitops
  → deploy.yml (auto-trigger)
  → Deploy do namespace 'dev'
```

#### Ręczny deploy do staging
```
GitHub UI → Actions → Deploy to AKS → Run workflow:
  - app_name: greeting-service
  - environment: staging
  - image_tag: abc1234
  
→ Deploy do namespace 'staging'
```

#### Promocja dev → prod (przez PR)
```
1. Sprawdź tag w dev:
   yq eval '.java-service.image.tag' apps/greeting-service/values-dev.yaml

2. Utwórz branch i zaktualizuj prod:
   git checkout -b promote-to-prod
   TAG=$(yq eval '.java-service.image.tag' apps/greeting-service/values-dev.yaml)
   yq eval -i ".java-service.image.tag = \"$TAG\"" apps/greeting-service/values-prod.yaml
   git commit -am "promote: greeting-service to prod - $TAG"
   git push

3. Otwórz PR → Review (ops-team) → Approve → Merge

4. Workflow deploy.yml wykryje zmianę w main i wdroży
   (lub użyj workflow_dispatch z tym tagiem)
```

### Troubleshooting

#### Workflow się nie wykonał po repository_dispatch
- Sprawdź, czy `GITOPS_PAT` w serwisie ma uprawnienia `repo`
- Sprawdź logi CI serwisu - czy `repository_dispatch` step się wykonał

#### Błąd: "App does not exist in gitops repo"
- Upewnij się, że `apps/{app_name}/` istnieje w gitops
- Sprawdź nazwę (case-sensitive!)

#### Błąd: "Values file not found"
- Upewnij się, że `apps/{app_name}/values-{environment}.yaml` istnieje
- Sprawdź nazwę środowiska (dev/staging/pre/prod)

#### Helm dependency update failuje
- Sprawdź, czy `funmagsoft.github.io/helm/charts` jest dostępny
- Sprawdź `Chart.yaml` - czy dependency jest poprawnie zdefiniowany

#### Pod nie startuje w AKS
- Sprawdź logi: `kubectl logs -n {env} deployment/{app_name}`
- Sprawdź czy image istnieje w ACR: `az acr repository show-tags --name {ACR} --repository {app_name}`

