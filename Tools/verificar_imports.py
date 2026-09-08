#!/usr/bin/env python3
"""
Verifica que cada ficheiro importa os módulos dos tipos que usa.

Um import em falta é um erro de compilação garantido e trivial de cometer
quando se move código entre ficheiros. Ao contrário da análise de assinaturas,
esta verificação tem quase zero falsos positivos: os módulos são deste
repositório e os tipos deles são conhecidos com exactidão.

Uso: python3 Tools/verificar_imports.py
"""
import re, pathlib, sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
MODULOS = RAIZ / 'Packages/BussolaCore/Sources'

DECL = re.compile(
    r'^\s*(?:public\s+|internal\s+|final\s+|@\w+\s+)*'
    r'(?:struct|class|enum|actor|protocol|extension)\s+([A-Z]\w*)', re.M)
IMPORT = re.compile(r'^\s*import\s+(\w+)', re.M)


def tipos_por_modulo():
    mapa = {}
    for pasta in sorted(MODULOS.iterdir()):
        if not pasta.is_dir():
            continue
        tipos = set()
        for f in pasta.rglob('*.swift'):
            texto = f.read_text(encoding='utf-8')
            # Só o que é público atravessa a fronteira do módulo.
            for m in re.finditer(
                r'^public\s+(?:final\s+)?(?:struct|class|enum|actor|protocol)\s+([A-Z]\w*)',
                texto, re.M
            ):
                tipos.add(m.group(1))
        mapa[pasta.name] = tipos
    return mapa


def main():
    modulos = tipos_por_modulo()
    for nome, tipos in modulos.items():
        print(f'{nome}: {len(tipos)} tipos públicos')
    print()

    # Ficheiros consumidores: a app, o partilhado, os widgets e os próprios
    # módulos (que também se importam entre si).
    alvos = []
    for pasta in ['App', 'Shared', 'Widgets', 'Packages/BussolaCore/Sources',
                  'Packages/BussolaCore/Tests']:
        alvos += sorted((RAIZ / pasta).rglob('*.swift'))

    falhas = 0
    for f in alvos:
        texto = f.read_text(encoding='utf-8')
        rel = f.relative_to(RAIZ)
        # O próprio módulo não se importa a si mesmo.
        proprio = next((m for m in modulos if f'/{m}/' in str(f)), None)
        importados = set(IMPORT.findall(texto))
        # `@testable import X` conta como import.
        importados |= set(re.findall(r'@testable\s+import\s+(\w+)', texto))

        corpo = re.sub(r'//.*', '', texto)
        corpo = re.sub(r'^\s*import .*$', '', corpo, flags=re.M)
        corpo = re.sub(r'/\*.*?\*/', '', corpo, flags=re.S)
        # Sem isto, uma etiqueta de interface como Section("Estado") era lida
        # como uma referência ao tipo Estado.
        corpo = re.sub(r'""".*?"""', '""', corpo, flags=re.S)
        corpo = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', corpo)

        for modulo, tipos in modulos.items():
            if modulo == proprio or modulo in importados:
                continue
            usados = sorted({
                t for t in tipos
                if re.search(r'(?<![\w.])' + re.escape(t) + r'(?![\w])', corpo)
            })
            if usados:
                falhas += 1
                print(f'✗ {rel}')
                print(f'    falta `import {modulo}` — usa {usados[:6]}'
                      + (' …' if len(usados) > 6 else ''))

    print()
    if falhas:
        print(f'{falhas} import(s) em falta.')
        return 1
    print(f'{len(alvos)} ficheiros: todos os imports entre módulos presentes.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
