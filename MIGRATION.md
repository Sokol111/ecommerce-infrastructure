# Migration Guide: Реструктуризація проекту

**Дата:** 29 жовтня 2025  
**Версія:** 1.0.0

## 📋 Огляд змін

Проект **ecommerce-infrastructure** був реструктуризований для кращої організації, масштабованості та підтримки.

### Основні зміни:

✅ **Організація середовищ** - конфігурації розділені по environments/  
✅ **Категоризація Helm values** - values організовані за призначенням  
✅ **Реорганізація Docker Compose** - compose файли в одному місці  
✅ **Категоризація скриптів** - scripts розділені по функціональності  
✅ **Документація** - додана повна документація проекту

---

## 🗂️ Порівняння структури

### До (стара структура):

```
ecommerce-infrastructure/
├── k3d-cluster.yaml           ❌
├── skaffold.yaml              ❌
├── docker/
│   └── docker-compose/        ❌
│       ├── mongo.yml
│       └── kafka.yml
├── helm/
│   └── helm-values/           ❌
│       ├── traefik.yaml
│       ├── grafana.yaml
│       └── ...
└── scripts/                   ❌
    ├── check-env.sh
    └── logs.sh
```

### Після (нова структура):

```
ecommerce-infrastructure/
├── ARCHITECTURE.md            ✅ НОВИЙ
├── environments/              ✅ НОВИЙ
│   └── local/
│       ├── k3d-cluster.yaml
│       ├── skaffold.yaml
│       └── README.md
├── docker/
│   └── compose/               ✅ ПЕРЕЙМЕНОВАНО
│       ├── mongo.yml
│       ├── kafka.yml
│       └── .env.example       ✅ НОВИЙ
├── helm/
│   └── values/                ✅ РЕОРГАНІЗОВАНО
│       ├── infrastructure/
│       ├── observability/
│       ├── storage/
│       └── misc/
├── scripts/                   ✅ РЕОРГАНІЗОВАНО
│   ├── setup/
│   └── monitoring/
└── docs/                      ✅ НОВИЙ
    ├── setup/
    ├── architecture/
    └── runbooks/
```

---

## 🔄 Детальні зміни

### 1. Environments (НОВИЙ)

**Що змінилось:**

- `k3d-cluster.yaml` → `environments/local/k3d-cluster.yaml`
- `skaffold.yaml` → `environments/local/skaffold.yaml`

**Чому:**

- Підготовка до підтримки різних середовищ (dev, staging, prod)
- Ізоляція конфігурацій
- Легше додавати нові середовища

**Дія:** Немає (Makefile автоматично використовує нові шляхи)

---

### 2. Docker Compose

**Що змінилось:**

- `docker/docker-compose/` → `docker/compose/`
- Додано `.env.example`

**Чому:**

- Коротша назва
- Стандартизація (compose замість docker-compose)
- Template для environment variables

**Дія:**

```bash
# Якщо використовували прямі шляхи (не через Makefile)
# Старе:
docker compose -f docker/docker-compose/mongo.yml up

# Нове:
docker compose -f docker/compose/mongo.yml up

# АБО краще через Makefile:
make infra-up
```

---

### 3. Helm Values

**Що змінилось:**

```
helm/helm-values/              →  helm/values/
├── traefik.yaml                  ├── infrastructure/
├── grafana.yaml                  │   └── traefik.yaml
├── loki.yaml                     ├── observability/
├── tempo.yaml                    │   ├── grafana.yaml
├── prometheus.yaml               │   ├── loki.yaml
├── otelcol.yaml                  │   ├── tempo.yaml
├── minio.yaml                    │   ├── prometheus.yaml
└── imgproxy.yaml                 │   └── otelcol.yaml
                                  ├── storage/
                                  │   └── minio.yaml
                                  └── misc/
                                      └── imgproxy.yaml
```

**Чому:**

- Логічна організація за призначенням
- Легше знайти потрібний файл
- Масштабується при додаванні нових сервісів

**Дія:** Немає (Skaffold автоматично використовує нові шляхи)

---

### 4. Scripts

**Що змінилось:**

```
scripts/                  →  scripts/
├── check-env.sh              ├── setup/
└── logs.sh                   │   └── check-env.sh
                              └── monitoring/
                                  └── logs.sh
```

**Чому:**

- Категоризація за функціональністю
- Готовність до додавання нових скриптів
- Зрозуміліша структура

**Дія:** Немає (Makefile автоматично використовує нові шляхи)

---

### 5. Документація (НОВИЙ)

**Що додано:**

- `ARCHITECTURE.md` - архітектурний огляд
- `docs/setup/quickstart.md` - швидкий старт
- `docs/runbooks/troubleshooting.md` - troubleshooting guide
- `environments/local/README.md` - опис local environment

**Чому:**

- Легше onboarding нових членів команди
- Центральне місце для документації
- Зменшення часу на розбір проблем

---

### 6. Makefile (ОНОВЛЕНО)

**Що змінилось:**

```makefile
# Старе
K3D_CONFIG ?= $(THIS_DIR)k3d-cluster.yaml
SKAFFOLD_CONFIG ?= $(THIS_DIR)skaffold.yaml
COMPOSE_DIR := $(THIS_DIR)docker/docker-compose

# Нове
ENV ?= local
ENV_DIR := $(THIS_DIR)environments/$(ENV)
K3D_CONFIG ?= $(ENV_DIR)/k3d-cluster.yaml
SKAFFOLD_CONFIG ?= $(ENV_DIR)/skaffold.yaml
COMPOSE_DIR := $(THIS_DIR)docker/compose
```

**Додано:**

- Змінна `ENV` для вибору середовища (default: local)
- Автоматичні шляхи на основі `ENV_DIR`

**Використання:**

```bash
# За замовчуванням (local)
make dev

# В майбутньому можна буде:
# make dev ENV=dev
```

---

### 7. .gitignore (ОНОВЛЕНО)

**Що додано:**

```gitignore
# Environments & Secrets
environments/**/secrets/
environments/**/*.secret.yaml
**/.env
.env.local
.env.*.local
```

**Чому:**

- Захист секретів
- Ізоляція локальних env файлів

---

## 🚀 Інструкції для команди

### Для розробників, які вже працювали з проектом:

#### 1. Оновити локальну копію

```bash
cd /path/to/ecommerce-infrastructure
git pull origin main
```

#### 2. Немає breaking changes!

Всі Makefile команди працюють як раніше:

```bash
make init         # Як і раніше
make dev          # Як і раніше
make dev-debug    # Як і раніше
make status       # Як і раніше
```

#### 3. Якщо були прямі посилання на файли

**Скрипти:**

```bash
# Старе
bash scripts/check-env.sh

# Нове
bash scripts/setup/check-env.sh

# АБО краще через Makefile
make check-env
```

**Docker Compose:**

```bash
# Старе
docker compose -f docker/docker-compose/mongo.yml up

# Нове
docker compose -f docker/compose/mongo.yml up

# АБО краще через Makefile
make infra-up
```

#### 4. Ознайомитись з новою документацією

```bash
# Прочитайте:
cat ARCHITECTURE.md
cat docs/setup/quickstart.md
cat docs/runbooks/troubleshooting.md
```

---

### Для нових членів команди:

1. Прочитайте [Quick Start Guide](docs/setup/quickstart.md)
2. Ознайомтесь з [Architecture](ARCHITECTURE.md)
3. Запустіть проект:
   ```bash
   make init
   make dev
   ```

---

## ⚠️ Breaking Changes

### НЕМАЄ BREAKING CHANGES! ✅

Makefile автоматично використовує нові шляхи. Всі команди працюють як раніше.

### Якщо використовували CI/CD:

Перевірте чи не прописані прямі шляхи до:

- `k3d-cluster.yaml` → `environments/local/k3d-cluster.yaml`
- `skaffold.yaml` → `environments/local/skaffold.yaml`
- `docker/docker-compose/` → `docker/compose/`
- `helm/helm-values/` → `helm/values/`

---

## 📊 Переваги нової структури

### 1. Масштабованість

- ✅ Легко додати нові середовища (dev, staging, prod)
- ✅ Готовність до cloud deployment

### 2. Організація

- ✅ Логічна категоризація файлів
- ✅ Легше знайти потрібне
- ✅ Зрозуміліша структура для нових

### 3. Документація

- ✅ Централізована документація
- ✅ Швидший onboarding
- ✅ Self-service troubleshooting

### 4. Підтримка

- ✅ Easier maintenance
- ✅ Стандартизація
- ✅ Best practices

---

## 🎯 Наступні кроки (Future)

### Коли з'явиться потреба:

1. **Dev/Staging/Production environments**

   ```
   environments/
   ├── local/       ✅ Є
   ├── dev/         📅 Майбутнє
   ├── staging/     📅 Майбутнє
   └── production/  📅 Майбутнє
   ```

2. **Terraform для cloud infrastructure**

   ```
   terraform/
   ├── modules/
   └── environments/
   ```

3. **CI/CD workflows**

   ```
   .github/workflows/
   ├── ci.yml
   ├── deploy-dev.yml
   └── deploy-prod.yml
   ```

4. **Tests**
   ```
   tests/
   ├── integration/
   └── smoke/
   ```

---

## ❓ FAQ

### Q: Чи потрібно щось змінювати в моєму workflow?

**A:** Ні, всі Makefile команди працюють як раніше.

### Q: Куди ділися k3d-cluster.yaml та skaffold.yaml?

**A:** Вони в `environments/local/`. Makefile автоматично їх знаходить.

### Q: Чому helm-values перейменовано в helm/values?

**A:** Для кращої організації з категоризацією (infrastructure, observability, storage, misc).

### Q: Що робити якщо щось не працює?

**A:** Дивіться [Troubleshooting Guide](docs/runbooks/troubleshooting.md) або запустіть `make status`.

### Q: Чи можна повернутись до старої структури?

**A:** Технічно так, але нова структура набагато краща. Спробуйте попрацювати - вам сподобається!

---

## 📝 Checklist для команди

- [ ] Прочитав цей MIGRATION.md
- [ ] Оновив локальну копію (`git pull`)
- [ ] Прочитав [Quick Start Guide](docs/setup/quickstart.md)
- [ ] Ознайомився з [Architecture](ARCHITECTURE.md)
- [ ] Запустив `make init` та переконався що все працює
- [ ] Прочитав [Troubleshooting](docs/runbooks/troubleshooting.md)
- [ ] Оновив закладки/notes з новими шляхами (якщо були)

---

## 💬 Зворотній зв'язок

Якщо є питання або пропозиції щодо нової структури:

- Створіть issue
- Обговоріть на team meeting
- Або звертайтесь до DevOps team

---

**Версія:** 1.0.0  
**Дата останнього оновлення:** 29 жовтня 2025
