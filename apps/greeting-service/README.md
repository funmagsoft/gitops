# greeting-service - GitOps Configuration

Konfiguracja Helm dla greeting-service we wszystkich środowiskach.

## Struktura

```
greeting-service/
├── Chart.yaml              # Helm chart z dependency na java-service@1.0.0
├── values-dev.yaml         # Konfiguracja środowiska DEV
├── values-staging.yaml     # Konfiguracja środowiska STAGING
├── values-pre.yaml         # Konfiguracja środowiska PRE-PROD
└── values-prod.yaml        # Konfiguracja środowiska PROD
```

## Różnice między środowiskami

| Parametr | DEV | STAGING | PRE | PROD |
|----------|-----|---------|-----|------|
| **Replicas** | 1 | 2 | 2 | 5 |
| **Memory Request** | 256Mi | 512Mi | 512Mi | 1Gi |
| **Memory Limit** | 512Mi | 1Gi | 1Gi | 2Gi |
| **CPU Request** | 100m | 200m | 200m | 500m |
| **CPU Limit** | 500m | 1000m | 1000m | 2000m |

## Struktura values (WAŻNE!)

Wszystkie wartości są **pod kluczem `java-service:`** (zgodnie z Helm dependency best practices):

```yaml
java-service:
  replicaCount: 1
  fullnameOverride: "greeting-service"
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
```

## Deployment

Deployment jest wykonywany automatycznie przez workflow `deploy.yml` w gitops repo:

### DEV (automatyczny)
- Każdy push do `main` w greeting-service trigguje auto-deploy do dev
- Workflow CI aktualizuje `values-dev.yaml` z nowym image tag

### STAGING / PRE / PROD (ręczny)
1. Sprawdź aktualny tag w dev:
   ```bash
   yq eval '.java-service.image.tag' values-dev.yaml
   ```

2. Utwórz PR z promocją:
   ```bash
   git checkout -b promote-to-staging
   TAG=$(yq eval '.java-service.image.tag' values-dev.yaml)
   yq eval -i ".java-service.image.tag = \"$TAG\"" values-staging.yaml
   git add values-staging.yaml
   git commit -m "promote: greeting-service to staging - $TAG"
   git push origin promote-to-staging
   ```

3. Review → Merge → Auto-deploy

## Historia zmian

Każda zmiana image tagu jest commitowana do tego repo, więc:
- `git log values-dev.yaml` - historia deployów do dev
- `git log values-prod.yaml` - historia deployów do prod

## Rollback

```bash
# Znajdź poprzednią wersję
git log --oneline values-prod.yaml

# Revert do poprzedniej wersji
git revert <commit-sha>
git push origin main
# Automatycznie wdroży poprzednią wersję
```

