#!/usr/bin/env python3
"""
Verificação estrutural de ficheiros Swift, sem compilador.

Não substitui `swift build` — não sabe nada de tipos. Apanha a classe de erros
que se comete a escrever muito código de uma vez: chavetas, parênteses e
parêntesis rectos desequilibrados, aspas por fechar, e comentários de bloco
por terminar.

Uso: python3 Tools/verificar_estrutura.py [raiz]
"""
import sys, pathlib

PARES = {'{': '}', '(': ')', '[': ']'}
FECHOS = {v: k for k, v in PARES.items()}


def analisar(texto):
    """Percorre o ficheiro carácter a carácter, respeitando strings e comentários."""
    problemas = []
    pilha = []            # (símbolo, linha)
    linha = 1
    i, n = 0, len(texto)

    em_linha_com = False
    prof_bloco_com = 0
    em_string = False
    em_string_multi = False
    escapou = False
    interp = 0            # profundidade de \( ... ) dentro de string

    while i < n:
        c = texto[i]
        prox = texto[i + 1] if i + 1 < n else ''
        prox3 = texto[i:i + 3]

        if c == '\n':
            linha += 1
            em_linha_com = False
            if em_string and not em_string_multi:
                problemas.append((linha - 1, 'string por fechar no fim da linha'))
                em_string = False
            i += 1
            continue

        if em_linha_com:
            i += 1
            continue

        if prof_bloco_com:
            if prox3[:2] == '/*':
                prof_bloco_com += 1; i += 2; continue
            if prox3[:2] == '*/':
                prof_bloco_com -= 1; i += 2; continue
            i += 1
            continue

        if em_string:
            if escapou:
                # Interpolação: \( abre uma expressão real dentro da string.
                if c == '(':
                    interp += 1
                    pilha.append(('(', linha))
                escapou = False
                i += 1
                continue
            if c == '\\':
                escapou = True; i += 1; continue
            if interp and c == ')':
                interp -= 1
                if pilha and pilha[-1][0] == '(':
                    pilha.pop()
                i += 1
                continue
            if interp:
                # Dentro da interpolação vale a sintaxe normal; simplificamos e
                # só seguimos até ao fecho, que é o caso esmagadoramente comum.
                i += 1
                continue
            if em_string_multi and prox3 == '"""':
                em_string = em_string_multi = False; i += 3; continue
            if not em_string_multi and c == '"':
                em_string = False; i += 1; continue
            i += 1
            continue

        # Fora de string e de comentário
        if prox3 == '"""':
            em_string = em_string_multi = True; i += 3; continue
        if c == '"':
            em_string = True; em_string_multi = False; i += 1; continue
        if c == '/' and prox == '/':
            em_linha_com = True; i += 2; continue
        if c == '/' and prox == '*':
            prof_bloco_com = 1; i += 2; continue

        if c in PARES:
            pilha.append((c, linha))
        elif c in FECHOS:
            if not pilha:
                problemas.append((linha, f"'{c}' a fechar sem abertura"))
            elif pilha[-1][0] != FECHOS[c]:
                aberto, ln = pilha[-1]
                problemas.append((linha, f"'{c}' fecha '{aberto}' aberto na linha {ln}"))
                pilha.pop()
            else:
                pilha.pop()
        i += 1

    for simbolo, ln in pilha:
        problemas.append((ln, f"'{simbolo}' nunca fecha"))
    if prof_bloco_com:
        problemas.append((linha, 'comentário de bloco por terminar'))
    if em_string:
        problemas.append((linha, 'string por fechar no fim do ficheiro'))
    return problemas


def main():
    raiz = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    ficheiros = sorted(raiz.rglob('*.swift'))
    if not ficheiros:
        print('Nenhum ficheiro .swift encontrado.'); return 1

    total_falhas = 0
    for f in ficheiros:
        problemas = analisar(f.read_text(encoding='utf-8'))
        rel = f.relative_to(raiz) if raiz in f.parents or raiz == f.parent else f
        if problemas:
            total_falhas += len(problemas)
            print(f'✗ {rel}')
            for ln, msg in problemas[:10]:
                print(f'    linha {ln}: {msg}')
        else:
            print(f'✓ {rel}  ({len(f.read_text(encoding="utf-8").splitlines())} linhas)')

    print()
    if total_falhas:
        print(f'{total_falhas} problema(s) estrutural(is) em {len(ficheiros)} ficheiros.')
        return 1
    print(f'{len(ficheiros)} ficheiros sem problemas estruturais.')
    print('Nota: isto não verifica tipos. Correr `swift test` no Mac.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
