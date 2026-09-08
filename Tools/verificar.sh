#!/usr/bin/env bash
# Todas as verificações que se conseguem fazer sem um compilador Swift.
#
# Não substituem `swift test`. Apanham três classes de erro que se cometem a
# escrever muito código de uma vez — estrutura, assinaturas e imports — e que de
# outra forma só apareceriam na primeira build no Xcode.
set -uo pipefail
cd "$(dirname "$0")/.."

falhou=0
alvos=(Packages/ App/ Shared/ Widgets/)

echo "── Estrutura (chavetas, parênteses, aspas) ──────────────────────"
for a in "${alvos[@]}"; do
    python3 Tools/verificar_estrutura.py "$a" | tail -2
done
echo

echo "── Assinaturas (chamadas vs declarações) ───────────────────────"
python3 Tools/verificar_referencias.py "${alvos[@]}" || falhou=1
echo

echo "── Imports entre módulos ───────────────────────────────────────"
python3 Tools/verificar_imports.py || falhou=1
echo

if [ "$falhou" -ne 0 ]; then
    echo "Há problemas por resolver."
    exit 1
fi
echo "Tudo limpo. Continua a faltar o compilador: correr"
echo "  swift test --package-path Packages/BussolaCore"
