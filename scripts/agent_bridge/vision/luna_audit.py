#!/usr/bin/env python3
"""Flujo de Visión: captura → Luna (visión) → contraste matemático → instrucciones.

Regla dura: Luna audita LO VISUAL (márgenes, jerarquía, consistencia), pero los
ratios de contraste se calculan con contrast_verify.py (Luna alucina ratios).

Uso:
    python3 luna_audit.py --screenshots /tmp/screenshots/
    python3 luna_audit.py --screenshots /tmp/screenshots/ --sin-luna  # solo contraste
"""
import base64
import json
import os
import subprocess
import sys
import urllib.request

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def enviar_a_luna(imagenes: list, prompt: str) -> str:
    """Envía screenshots a GPT-5.6-Luna (OpenRouter, visión)."""
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        return "(sin OPENROUTER_API_KEY — se omite la auditoría de visión)"

    contenido = [{"type": "text", "text": prompt}]
    for img in imagenes:
        with open(img, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        contenido.append({"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}})

    cuerpo = {
        "model": "openai/gpt-5.6-luna",
        "messages": [{"role": "user", "content": contenido}],
        "max_tokens": 2000,
    }
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(cuerpo).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.load(resp)["choices"][0]["message"]["content"]


PROMPT_LUNA = (
    "Sos auditora visual UI/UX de Rutmy (marca Scertta). Analizá estas capturas y "
    "respondé en ESPAÑOL, concisa y numerada: (1) márgenes, espaciado, jerarquía y "
    "responsividad; (2) consistencia del verde agua #64DEB2 como ACENTO (no fondo); "
    "(3) problemas de estado (focus/error/disabled). NO calcules ratios de contraste "
    "— eso lo hace un script matemático aparte. Listá problemas Alta/Media/Baja con "
    "corrección concreta para cada uno."
)


def main() -> int:
    args = sys.argv[1:]
    capturas_dir = "/tmp/screenshots"
    sin_luna = "--sin-luna" in args
    if "--screenshots" in args:
        capturas_dir = args[args.index("--screenshots") + 1]

    # 1. Contraste matemático (SIEMPRE)
    print("=== 1. CONTRASTE MATEMÁTICO (script propio) ===")
    subprocess.run([sys.executable, os.path.join(BASE, "vision", "contrast_verify.py")])

    # 2. Auditoría Luna (si hay capturas y API key)
    imagenes = sorted(
        os.path.join(capturas_dir, f) for f in os.listdir(capturas_dir) if f.endswith(".png")
    ) if os.path.isdir(capturas_dir) else []

    if imagenes and not sin_luna:
        print("\n=== 2. AUDITORÍA LUNA (visión) ===")
        print(enviar_a_luna(imagenes[:6], PROMPT_LUNA))
    elif imagenes:
        print(f"\n(saltando Luna — {len(imagenes)} capturas disponibles en {capturas_dir})")
    else:
        print(f"\n(sin capturas en {capturas_dir})")

    print("\n=== 3. INSTRUCCIONES PARA HERMES ===")
    print("Aplicar las correcciones de Luna solo tras validar el contraste con el script.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
