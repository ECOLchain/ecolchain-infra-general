#!/usr/bin/env bash
#
# Detecta modulos Terraform raiz (diretorios com backend.tf sob infra/terraform)
# afetados por um range de diff. Mudancas em modulos compartilhados em
# infra/terraform/modules/ marcam todos os modulos raiz que os consomem.
#
# Uso: detect-changed-modules.sh [--three-dot] <base-ref> [head-ref]
#   --three-dot  diff simetrico a partir do merge-base (equivale ao diff do PR)
#   <base-ref>   ref/commit base. Vazio ou "0000..." => considera TODOS os modulos
#   [head-ref]   default: HEAD
#
# Saidas (em $GITHUB_OUTPUT; stdout quando rodando local):
#   dirs / count             - todos os modulos afetados
#   prod_dirs / prod_count   - afetados cuja key do backend comeca com prod/
#   nonprod_dirs / nonprod_count - demais afetados
#
# Prefixos de key considerados nao-prod: dev|staging|stage|qa|test|sandbox.
# Key irreconhecivel cai em prod por seguranca (gate de aprovacao).
set -euo pipefail

THREE_DOT=0
BASE=""
HEAD="HEAD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --three-dot) THREE_DOT=1; shift ;;
    *) if [[ -z "$BASE" ]]; then BASE="$1"; else HEAD="$1"; fi; shift ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
ROOT="infra/terraform"

all_modules=$(find "$ROOT" -name 'backend.tf' \
  -not -path '*/.terraform/*' -not -path "$ROOT/modules/*" \
  -exec dirname {} \; | sort -u)

affected=()
in_list() { local x; for x in "${affected[@]:-}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }
add_all() { local d; while IFS= read -r d; do in_list "$d" || affected+=("$d"); done <<< "$all_modules"; }

if [[ -z "$BASE" || "$BASE" =~ ^0+$ ]]; then
  echo "::warning::base-ref invalida ('$BASE') - considerando todos os modulos" >&2
  add_all
elif ! changed=$( { [[ $THREE_DOT -eq 1 ]] && git diff --name-only "$BASE...$HEAD" -- "$ROOT" || git diff --name-only "$BASE..$HEAD" -- "$ROOT"; } 2>/dev/null ); then
  echo "::warning::git diff falhou para base '$BASE' - considerando todos os modulos" >&2
  add_all
else
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      "$ROOT"/modules/*/*)
        # modulo compartilhado alterado: marca todos os consumidores diretos
        mod=$(echo "$f" | cut -d/ -f4)
        while IFS= read -r d; do
          [[ -d "$d" ]] || continue
          for tf in "$d"/*.tf; do
            [[ -f "$tf" ]] || continue
            if grep -q "modules/${mod}" "$tf"; then
              in_list "$d" || affected+=("$d")
              break
            fi
          done
        done <<< "$all_modules"
        ;;
      *)
        # arquivo dentro de um modulo raiz: sobe ate achar o backend.tf
        dir=$(dirname "$f")
        while [[ "$dir" == "$ROOT"* && "$dir" != "." && "$dir" != "/" ]]; do
          if [[ -f "$dir/backend.tf" ]]; then
            in_list "$dir" || affected+=("$dir")
            break
          fi
          dir=$(dirname "$dir")
        done
        ;;
    esac
  done <<< "$changed"
fi

prod=()
nonprod=()
for d in "${affected[@]:-}"; do
  [[ -n "$d" ]] || continue
  envseg=$(sed -n 's/.*key[[:space:]]*=[[:space:]]*"\([^/]*\)\/.*/\1/p' "$d/backend.tf" | head -1) || envseg=""
  case "$envseg" in
    dev|staging|stage|qa|test|sandbox) nonprod+=("$d") ;;
    *) prod+=("$d") ;;
  esac
done

to_json() { printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0))'; }

echo "Modulos afetados:" >&2
printf '  %s\n' "${affected[@]:-}" >&2
echo "prod: ${prod[*]:-}  |  non-prod: ${nonprod[*]:-}" >&2

OUT="${GITHUB_OUTPUT:-/dev/stdout}"
{
  echo "dirs=$(to_json "${affected[@]:-}")"
  echo "count=${#affected[@]}"
  echo "prod_dirs=$(to_json "${prod[@]:-}")"
  echo "prod_count=${#prod[@]}"
  echo "nonprod_dirs=$(to_json "${nonprod[@]:-}")"
  echo "nonprod_count=${#nonprod[@]}"
} >> "$OUT"
