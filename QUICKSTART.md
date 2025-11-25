# GitOps - Quick Start dla deweloperów

**2 minuty do pierwszego deployu** 🚀

---

## Twój serwis już korzysta z GitOps?

### Deploy do dev (automatyczny)

```bash
git commit -m "feat: my feature"
git push origin main
```

### Sprawdź co jest wdrożone

```bash
# W repo gitops:
./scripts/status.sh my-service
```

### Rollback

```bash
# W repo gitops:
git revert HEAD
git push origin main
```

**Więcej**: [README.md](README.md)

---

## Dodajesz nowy serwis?

### 1. Utwórz konfigurację w gitops

```bash
cd gitops

# Tworzy apps/my-service/ + Chart.yaml + values-*.yaml
./scripts/add-service.sh my-service

git add apps/my-service/
git commit -m "feat(apps): add my-service"
git push origin main
```

### 2. Zmodyfikuj workflow w serwisie

**`.github/workflows/cicd.yml`** (skopiuj z greeting-service):

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: funmagsoft/github-actions-templates/.github/workflows/build.yml@main
    with:
      app_name: my-service
    secrets:
      AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

  deploy-to-dev:
    name: "Deploy to Dev (GitOps)"
    needs: build
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - name: Trigger GitOps deployment
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.GITOPS_PAT }}
          repository: funmagsoft/gitops
          event-type: deploy
          client-payload: |
            {
              "app_name": "my-service",
              "environment": "dev",
              "image_tag": "${{ needs.build.outputs.image_tag }}",
              "acr_server": "${{ vars.ACR_LOGIN_SERVER }}"
            }
```

### 3. Dodaj secrets w serwisie (GitHub Settings)

**Secrets**:

- `GITOPS_PAT` (GitHub PAT z uprawnieniem `repo`)
- `AZURE_CLIENT_ID`,
- `AZURE_TENANT_ID`,
- `AZURE_SUBSCRIPTION_ID`

**Variables**:

- `ACR_LOGIN_SERVER` (np. `hycomcminternal.azurecr.io`)

### 4. Test

```bash
cd my-service
git commit --allow-empty -m "test: GitOps"
git push origin main

# Obserwuj:
# 1. GitHub Actions → my-service → cicd
# 2. GitHub Actions → gitops → deploy
# 3. kubectl get pods -n dev
```

**Więcej szczegółów**: [README.md#dodawanie-nowego-serwisu](README.md#-dodawanie-nowego-serwisu)

---

## Promocja do staging/prod?

```bash
# Dev → staging
./scripts/promote.sh my-service dev staging

# Staging → prod (po PR review)
./scripts/promote.sh my-service staging prod
```

**Więcej**: [README.md#promocja](README.md#-promocja-między-środowiskami)

---

## Problem?

**Debugging**: [README.md#debugging](README.md#-debugging)  
**FAQ**: [README.md](README.md)  
**Slack**: #platform-team

---

**Pełna dokumentacja**: [README.md](README.md)
