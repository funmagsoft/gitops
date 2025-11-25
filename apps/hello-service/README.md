# hello-service - GitOps Configuration

Konfiguracja Helm dla hello-service we wszystkich środowiskach.

## Struktura

```
hello-service/
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

## Deployment

Deployment jest wykonywany automatycznie przez workflow `deploy.yml` w gitops repo.

Szczegóły analogiczne do greeting-service - zobacz `../greeting-service/README.md`

