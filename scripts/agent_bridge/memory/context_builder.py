#!/usr/bin/env python3
"""Construye el contexto compartido (el "clip") para todos los agentes.

El clip incluye:
  1. .cursorrules (Biblia Maestra) — SIEMPRE, sin excepción.
  2. memory/decisions.json — decisiones previas (Docker ZimaOS, contraste, H3...).
  3. Graphify/Kai Vault — nodos del grafo relacionados con la consulta (si habilitado).

Uso:
    python3 context_builder.py [--consulta "tema"]
"""
import json
import os
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIBLIA = "/DATA/AppData/scertta_workspace/scertta-app/.cursorrules"
DECISIONES = os.path.join(BASE, "memory", "decisions.json")


def cargar_biblia() -> str:
    try:
        with open(BIBLIA, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return "(Biblia Maestra no encontrada)"


def cargar_decisiones() -> list:
    try:
        with open(DECISIONES, encoding="utf-8") as f:
            return json.load(f).get("decisiones", [])
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def consultar_graphify(tema: str) -> str:
    """Consulta el grafo Graphify via MCP (graph-query). Placeholder funcional:
    si no hay MCP disponible, devuelve cadena vacía SIN inventar."""
    # En producción, aquí se invoca el MCP graph-query (search_nodes/get_neighbors).
    # Por ahora devolvemos vacío para no alucinar resultados del grafo.
    return ""


def construir_contexto(tema: str = "") -> str:
    partes = [
        "=" * 60,
        "CONTEXTO COMPARTIDO (PAPERCLIP) — todo agente DEBE leer antes de actuar",
        "=" * 60,
        "",
        "### 1. BIBLIA MAESTRA (.cursorrules)",
        cargar_biblia(),
        "",
        "### 2. DECISIONES PREVIAS",
    ]
    for d in cargar_decisiones():
        partes.append(
            f"- [{d['fecha']}] {d['tema']}: {d['decision']}"
        )
    if tema:
        g = consultar_graphify(tema)
        partes += ["", f"### 3. GRAPHIFY (consulta: {tema})", g or "(sin nodos disponibles)"]
    return "\n".join(partes)


def main() -> int:
    tema = ""
    if "--consulta" in sys.argv:
        i = sys.argv.index("--consulta")
        if i + 1 < len(sys.argv):
            tema = sys.argv[i + 1]
    print(construir_contexto(tema))
    return 0


if __name__ == "__main__":
    sys.exit(main())
