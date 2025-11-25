# GitOps Repository

Centralne repozytorium konfiguracji deploymentów dla wszystkich serwisów Java na AKS.

**Szybki start**: [QUICKSTART.md](QUICKSTART.md) - 2 minuty do pierwszego deployu

## Quick Start

### Dla deweloperów (twój serwis już używa GitOps)

Push do `main` → automatyczny deploy do `dev`:

```bash
git commit -m "feat: my feature"
git push origin main
```

Sprawdź status:

```bash
# Co jest wdrożone w dev?
cat apps/greeting-service/values-dev.yaml | grep tag

# Historia deployów
git log --oneline apps/greeting-service/values-dev.yaml
```

Rollback (jeśli coś poszło nie tak):

```bash
git revert HEAD
git push origin main
```

---

## 📁 Struktura

```
gitops/
├── apps/                    # Konfiguracje serwisów
│   ├── greeting-service/
│   │   ├── Chart.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   ├── values-pre.yaml
│   │   └── values-prod.yaml
│   └── hello-service/
│       └── ...
├── scripts/                # Narzędzia pomocnicze
│   ├── add-service.sh      # Dodaj nowy serwis
│   └── promote.sh          # Promuj między środowiskami
└── .github/workflows/
    └── deploy.yml          # Workflow CD
```

---

## Jak to działa (na przykładzie greeting-service)

### 1. Push kodu do serwisu

```bash
# W repo greeting-service
git commit -m "fix: bug"
git push origin main
```

### 2. CI (w greeting-service)

Workflow `.github/workflows/cicd.yml`:

- Maven build + testy
- Docker build
- Push do ACR: `hycomcminternal.azurecr.io/greeting-service:abc1234`
- Trigger GitOps (repository_dispatch)

### 3. CD (w gitops - to repo)

Workflow `.github/workflows/deploy.yml`:

1. Aktualizuje `apps/greeting-service/values-dev.yaml`:

   ```yaml
   java-service:
     image:
       repository: "hycomcminternal.azurecr.io/greeting-service"
       tag: "abc1234"  # ← nowy tag
   ```

2. Commituje zmiany (audit trail)
3. Helm upgrade na AKS namespace `dev`

### 4. Rezultat

Pod `greeting-service` w namespace `dev` jest zrestartowany z nowym image.

**Pełny czas**: ~5-8 minut (push → deployed)

---

## Dodawanie nowego serwisu

### Opcja 1: Użyj skryptu (ZALECANE)

```bash
./scripts/add-service.sh my-new-service
```

Skrypt:

- Tworzy `apps/my-new-service/` z Chart.yaml + values-*.yaml
- Generuje podstawową konfigurację (1 replica dev, 5 prod)
- Wyświetla następne kroki

### Opcja 2: Ręcznie

1. **Skopiuj strukturę**:

   ```bash
   cp -r apps/greeting-service apps/my-new-service
   ```

2. **Edytuj pliki**:

   ```bash
   # Chart.yaml - zmień name
   sed -i '' 's/greeting-service/my-new-service/g' apps/my-new-service/Chart.yaml
   
   # values-*.yaml - zmień fullnameOverride
   find apps/my-new-service -name "values-*.yaml" -exec \
     sed -i '' 's/greeting-service/my-new-service/g' {} \;
   ```

3. **Dostosuj resources** (opcjonalnie):

   ```bash
   # values-prod.yaml - zwiększ replicas/resources jeśli potrzeba
   vi apps/my-new-service/values-prod.yaml
   ```

4. **Commit i push**:

   ```bash
   git add apps/my-new-service/
   git commit -m "feat: add my-new-service config"
   git push origin main
   ```

5. **Zmodyfikuj serwis (w jego repo)**: `my-new-service/.github/workflows/cicd.yml`:
   
   ```yaml
   jobs:
     build:
       uses: funmagsoft/github-actions-templates/.github/workflows/build.yml@main
       with:
         app_name: my-new-service
       secrets:
         AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
         AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
         AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

     deploy-to-dev:
       needs: build
       if: github.event_name == 'push'
       runs-on: ubuntu-latest
       steps:
         - uses: peter-evans/repository-dispatch@v3
           with:
             token: ${{ secrets.GITOPS_PAT }}
             repository: funmagsoft/gitops
             event-type: deploy
             client-payload: |
               {
                 "app_name": "my-new-service",
                 "environment": "dev",
                 "image_tag": "${{ needs.build.outputs.image_tag }}",
                 "acr_server": "${{ vars.ACR_LOGIN_SERVER }}"
               }
   ```

   **Secrets wymagane w serwisie**:

   - `GITOPS_PAT` (GitHub PAT z uprawnieniem `repo`)
   - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (dla ACR)

   **Variables wymagane**:

   - `ACR_LOGIN_SERVER` (np. `hycomcminternal.azurecr.io`)

6. **Test**:

   ```bash
   # Push do serwisu
   cd my-new-service
   git commit --allow-empty -m "test: GitOps deploy"
   git push origin main
   
   # Obserwuj:
   # 1. GitHub Actions w my-new-service (build + deploy-to-dev)
   # 2. GitHub Actions w gitops (deploy)
   # 3. kubectl get pods -n dev
   ```

---

## Promocja między środowiskami

### DEV → automatyczny
Każdy push do `main` w serwisie → auto-deploy do `dev`.

### DEV → STAGING (ręczny)

**Opcja 1: Użyj skryptu**

```bash
./scripts/promote.sh greeting-service dev staging
```

**Opcja 2: Ręcznie (PR)**

```bash
# 1. Sprawdź aktualny tag w dev
TAG=$(yq eval '.java-service.image.tag' apps/greeting-service/values-dev.yaml)
echo "Tag w dev: $TAG"

# 2. Utwórz branch
git checkout -b promote-greeting-staging

# 3. Zaktualizuj staging
yq eval -i ".java-service.image.tag = \"$TAG\"" apps/greeting-service/values-staging.yaml

# 4. Commit i push
git add apps/greeting-service/values-staging.yaml
git commit -m "promote: greeting-service to staging - $TAG"
git push origin promote-greeting-staging

# 5. Otwórz PR → Review → Merge
# Po merge: automatyczny deploy do staging
```

### STAGING → PRE → PROD
Analogicznie, ale dla PROD **WYMAGANY** review od zespołu ops (GitHub Environments).

---

## Debugging

### Pod nie startuje?

```bash
# Sprawdź logi
kubectl logs -n dev deployment/greeting-service --tail=50

# Sprawdź events
kubectl get events -n dev --sort-by='.lastTimestamp' | grep greeting

# Sprawdź czy image istnieje w ACR
az acr repository show-tags --name hycomcminternal \
  --repository greeting-service --output table
```

### Workflow w gitops się nie uruchomił?

```bash
# Sprawdź logi w serwisie (job deploy-to-dev)
# Przejdź do: GitHub Actions → serwis → cicd → deploy-to-dev
# Sprawdź czy repository_dispatch się wykonał

# Sprawdź czy GITOPS_PAT ma uprawnienia
# Settings → Secrets → GITOPS_PAT (scope: repo)
```

### Deployment failuje w Helm?

```bash
# Sprawdź dependency
cd apps/greeting-service
helm dependency update

# Test lokalnie
helm template greeting-service . -f values-dev.yaml

# Sprawdź czy java-service chart jest dostępny
helm repo add funmagsoft https://funmagsoft.github.io/helm/charts
helm repo update
helm search repo java-service
```

---

## Monitoring

### Co jest wdrożone gdzie?

```bash
# Dev
yq eval '.java-service.image.tag' apps/*/values-dev.yaml

# Prod
yq eval '.java-service.image.tag' apps/*/values-prod.yaml

# Wszystkie środowiska dla greeting-service
for env in dev staging pre prod; do
  echo "$env: $(yq eval '.java-service.image.tag' apps/greeting-service/values-$env.yaml)"
done
```

### Historia deployów

```bash
# Ostatnie 10 deployów do dev
git log --oneline -10 apps/greeting-service/values-dev.yaml

# Kto i kiedy deployował do prod
git log --format="%h %an %ar - %s" apps/greeting-service/values-prod.yaml

# Diff między środowiskami
diff <(yq eval '.java-service.image.tag' apps/greeting-service/values-dev.yaml) \
     <(yq eval '.java-service.image.tag' apps/greeting-service/values-prod.yaml)
```

---

## Rollback

### Szybki rollback (prod)

```bash
# 1. Znajdź poprzednią wersję
git log --oneline apps/greeting-service/values-prod.yaml
# Przykład: abc1234 deploy: greeting-service to prod - v2.0.1

# 2. Revert
git revert HEAD
git push origin main

# Automatycznie wdroży poprzednią wersję na prod
```

### Rollback do konkretnej wersji

```bash
# 1. Sprawdź historię
git log --oneline apps/greeting-service/values-prod.yaml

# 2. Zobacz tag w konkretnym commicie
git show abc1234:apps/greeting-service/values-prod.yaml | grep tag

# 3. Ręcznie ustaw ten tag
yq eval -i ".java-service.image.tag = \"v2.0.1\"" \
  apps/greeting-service/values-prod.yaml

git add apps/greeting-service/values-prod.yaml
git commit -m "rollback: greeting-service to v2.0.1"
git push origin main
```

---

## Konfiguracja

### Secrets (w tym repo gitops)

```
AZURE_CLIENT_ID          # OIDC do Azure
AZURE_TENANT_ID          # OIDC do Azure  
AZURE_SUBSCRIPTION_ID    # OIDC do Azure
AKS_RG                   # Resource Group dla AKS
AKS_NAME                 # Nazwa klastra AKS
```

### Variables (w tym repo gitops)

```
ACR_LOGIN_SERVER         # np. hycomcminternal.azurecr.io
```

### Secrets w serwisach (greeting-service, hello-service, etc.)

```
GITOPS_PAT               # GitHub PAT z uprawnieniem 'repo'
AZURE_CLIENT_ID          # dla ACR push
AZURE_TENANT_ID          # dla ACR push
AZURE_SUBSCRIPTION_ID    # dla ACR push
```

### Variables w serwisach

```
ACR_LOGIN_SERVER         # dla client-payload do gitops
```

---

## Narzędzia

### Instalacja yq (jeśli nie masz)

```bash
# macOS
brew install yq

# Linux
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### Alias-y pomocnicze (opcjonalnie)

```bash
# Dodaj do ~/.bashrc lub ~/.zshrc
alias gitops-status='for env in dev staging pre prod; do echo "$env: $(yq eval ".java-service.image.tag" apps/greeting-service/values-$env.yaml)"; done'
alias gitops-history='git log --oneline -10 apps/greeting-service/values-dev.yaml'
```

---

## Więcej informacji

- **Szczegóły workflow**: `.github/workflows/README.md`
- **Przykład konfiguracji**: `apps/greeting-service/README.md`
- **Troubleshooting**: `.github/workflows/README.md#troubleshooting`

---

## Wsparcie

**Problemy?**

1. Sprawdź [Debugging](#-debugging)
2. Zobacz logi w GitHub Actions (serwis + gitops)
3. Sprawdź `kubectl` w AKS
4. Skontaktuj się z zespołem Platform/Ops

**Pytania?**

- Slack: #platform-team
- GitHub: otwórz issue w tym repo
