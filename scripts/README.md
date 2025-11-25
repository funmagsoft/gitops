# GitOps Scripts

Narzędzia pomocnicze do zarządzania deploymentami.

## 🛠️ Dostępne skrypty

### `add-service.sh` - Dodaj nowy serwis

Tworzy strukturę dla nowego serwisu (Chart.yaml + 4x values-*.yaml).

**Użycie**:
```bash
./scripts/add-service.sh <nazwa-serwisu>
```

**Przykład**:
```bash
./scripts/add-service.sh payment-service
```

**Co robi**:
- Tworzy `apps/payment-service/`
- Generuje Chart.yaml
- Generuje values-dev.yaml, values-staging.yaml, values-pre.yaml, values-prod.yaml
- Tworzy README.md
- Wyświetla następne kroki

---

### `promote.sh` - Promuj między środowiskami

Promuje image tag z jednego środowiska do drugiego (przez PR).

**Użycie**:
```bash
./scripts/promote.sh <serwis> <źródło> <cel>
```

**Przykład**:
```bash
./scripts/promote.sh greeting-service dev staging
```

**Co robi**:
- Pobiera tag ze źródłowego środowiska
- Tworzy nowy branch
- Aktualizuje tag w docelowym środowisku
- Commituje i pushuje
- Wyświetla instrukcje do utworzenia PR

---

### `status.sh` - Sprawdź status deploymentów

Wyświetla aktualny stan deploymentów (tagi, replicas).

**Użycie**:
```bash
# Wszystkie serwisy
./scripts/status.sh

# Konkretny serwis
./scripts/status.sh greeting-service
```

**Przykład output** (wszystkie serwisy):
```
📦 Wszystkie serwisy:

  greeting-service          | Dev: abc1234        | Prod: v2.0.1
  hello-service             | Dev: def5678        | Prod: v1.5.0
  payment-service           | Dev: latest         | Prod: v3.2.0
```

**Przykład output** (konkretny serwis):
```
🔍 Serwis: greeting-service

  dev        | Tag: abc1234             | Replicas: 1
  staging    | Tag: abc1234             | Replicas: 2
  pre        | Tag: v2.0.1              | Replicas: 2
  prod       | Tag: v2.0.1              | Replicas: 5

📜 Ostatnie 5 deployów do dev:
abc1234 deploy: greeting-service to dev - abc1234
def5678 deploy: greeting-service to dev - def5678
...
```

---

## 🔧 Wymagania

Wszystkie skrypty wymagają **yq** (YAML processor):

**Instalacja**:
```bash
# macOS
brew install yq

# Linux
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Weryfikacja
yq --version
```

---

## 💡 Przykładowe workflow

### Dodanie nowego serwisu

```bash
# 1. Utwórz strukturę w gitops
./scripts/add-service.sh my-new-service

# 2. Dostosuj konfigurację (jeśli potrzeba)
vi apps/my-new-service/values-prod.yaml

# 3. Commit i push
git add apps/my-new-service/
git commit -m "feat(apps): add my-new-service"
git push origin main

# 4. Zmodyfikuj workflow w serwisie (patrz: główny README.md)

# 5. Test
cd my-new-service
git push origin main
```

### Promocja do produkcji

```bash
# 1. Sprawdź co jest w dev
./scripts/status.sh greeting-service

# 2. Promuj dev → staging
./scripts/promote.sh greeting-service dev staging

# 3. Po merge PR: sprawdź status
./scripts/status.sh greeting-service

# 4. Jeśli staging OK: promuj staging → prod
./scripts/promote.sh greeting-service staging prod
```

---

## 🤝 Rozwój skryptów

Chcesz dodać nowy skrypt? Super!

1. Utwórz plik `scripts/nazwa.sh`
2. Dodaj shebang: `#!/bin/bash`
3. Dodaj opis użycia na początku
4. Dodaj dokumentację tutaj (w tym README)
5. Sprawdź czy działa: `chmod +x scripts/nazwa.sh && ./scripts/nazwa.sh`

**Best practices**:
- Używaj `set -e` (fail fast)
- Waliduj argumenty
- Wyświetlaj jasne komunikaty
- Dodaj `--help` option
- Testuj na przykładzie greeting-service

