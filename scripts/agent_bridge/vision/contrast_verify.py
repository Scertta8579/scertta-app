#!/usr/bin/env python3
"""Verificación MATEMÁTICA de contraste WCAG.

Regla dura: Luna (visión) NO calcula ratios WCAG de forma fiable — alucina.
Este script calcula los ratios reales (fórmula WCAG 2.x de luminancia relativa).

Uso:
    python3 contrast_verify.py "#64DEB2" "#0F172A"
    python3 contrast_verify.py --pares "#64DEB2,#0F172A" "#0E7C5E,#FFFFFF"
"""
import sys


def luminancia(hex_color: str) -> float:
    """Luminancia relativa según WCAG 2.x (sRGB)."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

    def lineal(c: float) -> float:
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * lineal(r) + 0.7152 * lineal(g) + 0.0722 * lineal(b)


def ratio_contraste(a: str, b: str) -> float:
    la, lb = luminancia(a), luminancia(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def veredicto(r: float) -> str:
    if r >= 7.0:
        return "AAA"
    if r >= 4.5:
        return "AA"
    if r >= 3.0:
        return "AA-grande"
    return "FALLA"


# Ratios canónicos del proyecto (verificados 2026-08-13)
CANONICOS = {
    ("#64DEB2", "#0F172A"): 10.74,   # verde agua sobre oscuro → OK
    ("#64DEB2", "#FFFFFF"): 1.66,    # verde agua sobre claro → FALLA
    ("#0E7C5E", "#FFFFFF"): 5.17,    # verde oscuro sobre claro → AA
    ("#FFFFFF", "#64DEB2"): 1.66,    # blanco sobre verde agua → FALLA
    ("#0F172A", "#64DEB2"): 10.74,   # texto oscuro sobre verde agua → AAA
    ("#64DEB2", "#FAFAF5"): 1.59,    # verde agua sobre sand → FALLA
}


def main() -> int:
    args = sys.argv[1:]
    pares = []
    if args and args[0] == "--pares":
        for p in args[1:]:
            a, b = p.split(",")
            pares.append((a, b))
    elif len(args) >= 2:
        pares.append((args[0], args[1]))
    else:
        # Sin args: verifica los ratios canónicos
        print("=== Ratios canónicos Scertta/Rutmy (verificados) ===")
        for (a, b), esperado in CANONICOS.items():
            r = ratio_contraste(a, b)
            ok = "OK" if abs(r - esperado) < 0.02 else f"DISCREPANCIA (esperado {esperado})"
            print(f"  {a} sobre {b}: {r:.2f} → {veredicto(r)} [{ok}]")
        return 0

    for a, b in pares:
        r = ratio_contraste(a, b)
        print(f"{a} sobre {b}: {r:.2f}:1 → {veredicto(r)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
