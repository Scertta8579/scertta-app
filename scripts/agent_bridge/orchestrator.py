#!/usr/bin/env python3
"""Orquestador Paperclip — coordina Luna + DeepSeek + Codex bajo supervisión de Hermes.

Los agentes NO se encadenan: cada uno recibe el MISMO contexto compartido (clip)
y responde en paralelo. El orquestador recoge los resultados en el bus.

Uso:
    python3 orchestrator.py --tarea "auditar contraste PWA" --agentes luna,deepseek
"""
import json
import os
import sys
import time
import urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(BASE, "memory"))
from context_builder import construir_contexto  # noqa: E402


def cargar_config():
    import yaml  # PyYAML; si no está, cae a dict vacío
    try:
        with open(os.path.join(BASE, "config.yaml"), encoding="utf-8") as f:
            return yaml.safe_load(f)
    except Exception:
        return {}


def enviar_a_modelo(agente: dict, contexto: str, tarea: str) -> str:
    """Envía la tarea a un modelo vía API OpenAI-compatible."""
    key = os.environ.get(agente.get("env_key", ""), "")
    if not key:
        return f"[{agente['descripcion']}] SIN clave API ({agente.get('env_key')}). Se omite la llamada remota."

    cuerpo = {
        "model": agente["modelo"],
        "messages": [
            {"role": "system", "content": "Sos un agente especialista. Respondé en español."},
            {"role": "user", "content": f"CONTEXTO:\n{contexto}\n\nTAREA:\n{tarea}"},
        ],
        "max_tokens": 2000,
    }
    req = urllib.request.Request(
        agente["endpoint"],
        data=json.dumps(cuerpo).encode(),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.load(resp)
        return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"[{agente['descripcion']}] ERROR: {e}"


def main() -> int:
    args = sys.argv[1:]
    tarea = ""
    agentes_nombres = ["luna", "deepseek"]
    if "--tarea" in args:
        tarea = args[args.index("--tarea") + 1]
    if "--agentes" in args:
        agentes_nombres = args[args.index("--agentes") + 1].split(",")

    config = cargar_config()
    contexto = construir_contexto()

    resultados = {}
    for nombre in agentes_nombres:
        agente = config.get("agentes", {}).get(nombre, {})
        if not agente:
            resultados[nombre] = f"[desconocido] agente '{nombre}' no está en config.yaml"
            continue
        print(f"→ Despachando a {nombre} ({agente['descripcion']})...", file=sys.stderr)
        resultados[nombre] = enviar_a_modelo(agente, contexto, tarea or "resumí el contexto")

    # Escribir resultados al bus (outbox)
    bus_out = os.path.join(BASE, "bus", "outbox")
    os.makedirs(bus_out, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    with open(os.path.join(bus_out, f"{ts}.json"), "w", encoding="utf-8") as f:
        json.dump({"tarea": tarea, "agentes": resultados}, f, ensure_ascii=False, indent=2)

    print("\n=== RESULTADOS ===")
    for nombre, texto in resultados.items():
        print(f"\n--- {nombre} ---\n{texto[:1500]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
