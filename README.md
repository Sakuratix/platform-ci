# platform-ci

[![self-test](https://github.com/Sakuratix/platform-ci/actions/workflows/self-test.yml/badge.svg)](https://github.com/Sakuratix/platform-ci/actions/workflows/self-test.yml)

Переиспользуемые GitHub Actions workflow, чтобы каждый репозиторий не собирал CI с нуля. Репозиторий подключает нужное одной строкой `uses:` и сразу получает сканирование, SBOM, подпись образов и проверки IaC, одинаковые везде.

| Workflow | Что делает |
| --- | --- |
| [`docker.yml`](.github/workflows/docker.yml) | hadolint → buildx с кэшем (и multi-arch через `platforms: linux/amd64,linux/arm64`) → Trivy (падает на HIGH/CRITICAL с доступным фиксом) → SBOM в SPDX → push в GHCR → подпись cosign keyless. На pull request только проверяет, ничего не публикует. |
| [`terraform.yml`](.github/workflows/terraform.yml) | `fmt`, `init -backend=false`, `validate`, `tflint`. В pull request оставляет один комментарий с таблицей результатов и обновляет его на следующих пушах вместо спама. |
| [`security.yml`](.github/workflows/security.yml) | gitleaks по **всей** истории git (ключ, который закоммитили и «удалили» следующим коммитом, всё ещё утёк) + Trivy по файловой системе: уязвимые зависимости в lock-файлах и опасные настройки в Dockerfile, манифестах, Helm и Terraform. Находки уходят во вкладку Security как SARIF. |
| [`helm.yml`](.github/workflows/helm.yml) | `helm lint --strict`, рендер, `kubeconform` по схемам Kubernetes и CRD, `kube-linter` на best practices: пробы, лимиты, read-only FS, anti-affinity. |

## Подключение

```yaml
# .github/workflows/ci.yml в любом репозитории
on: { push: { branches: [main] }, pull_request: {} }

jobs:
  image:
    uses: Sakuratix/platform-ci/.github/workflows/docker.yml@v1
    with:
      context: app
    permissions: { contents: read, packages: write, id-token: write }

  terraform:
    uses: Sakuratix/platform-ci/.github/workflows/terraform.yml@v1
    with:
      working-directory: terraform
    permissions: { contents: read, pull-requests: write }

  helm:
    uses: Sakuratix/platform-ci/.github/workflows/helm.yml@v1
    with:
      chart: helm/app
      set: ingress.enabled=true

  security:
    uses: Sakuratix/platform-ci/.github/workflows/security.yml@v1
    permissions: { contents: read, security-events: write }
```

Живой пример: [infra-lab](https://github.com/Sakuratix/infra-lab/blob/main/.github/workflows/ci.yml) собирается именно так.

## Проверить подпись и SBOM

```bash
# подпись привязана к workflow и репозиторию, ключей нет
cosign verify ghcr.io/sakuratix/infra-lab:latest \
  --certificate-identity-regexp 'https://github.com/Sakuratix/platform-ci/.github/workflows/docker.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# SBOM лежит артефактом прогона: sbom-<sha>.spdx.json
```

## Решения

- **Одна точка правды.** Обновил версию Trivy или правило проверки здесь, и все репозитории получили это на следующем прогоне. Без копипасты YAML по десяти репозиториям.
- **Pull request ничего не публикует.** Push и подпись только из основной ветки, поэтому чужой форк не положит образ в registry.
- **`ignore-unfixed: true`.** Сборка падает только на уязвимостях, для которых уже есть исправление: на остальные команда всё равно не может повлиять, а красный CI без действия быстро начинают игнорировать.
- **Keyless cosign.** Подпись выдаётся через OIDC-токен GitHub на конкретный workflow. Нет приватного ключа, который нужно хранить и ротировать.
- **Секреты и пользовательский ввод не подставляются в `run:` напрямую**, только через `env`. Это защита от script injection в GitHub Actions.
- **Самотесты.** [`self-test.yml`](.github/workflows/self-test.yml) прогоняет каждый workflow на фикстурах из `tests/fixtures` и проверяет сами workflow через `actionlint`.

## Версии

Теги `v1`, `v1.x.y`. Ломающие изменения только в новой мажорной версии. Для максимальной предсказуемости можно закрепить конкретный SHA вместо тега.

## Versions

Releases are tagged `vX.Y.Z` and never move. The `v1` tag is moved by [`major-tag.yml`](.github/workflows/major-tag.yml) to the newest `v1.x.y` release: pin `@v1` to get fixes automatically, or `@v1.0.0` to freeze.
