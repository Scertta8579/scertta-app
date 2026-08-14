# Agent Bridge — Orquestación Multi-Agente Paperclip (Luna + DeepSeek + Codex)

> "Opción B Evolucionada" — comunicación fluida entre modelos bajo supervisión de Hermes.
> Filosofía Paperclip: los agentes NO se pasan mensajes secuenciales, sino que comparten
> un **contexto persistente** (clipboard de memoria) que todos leen y escriben, sin perder
> el hilo ni la memoria.

## Principios

1. **Memoria única compartida** — `.cursorrules` (Biblia Maestra) + `memory/decisions.json` +
   Graphify Vault son el "clip" que todo agente consulta antes de actuar. Ningún agente
   decide sin ese contexto.
2. **Especialistas en paralelo** — cada modelo hace lo que mejor sabe, coordinados por el
   orquestador, no encadenados:
   - **Luna (GPT-5.6)** → Visión, UI/UX, WCAG, contraste matemático.
   - **DeepSeek** → Lógica, SQL, arquitectura, análisis.
   - **Codex** → Terminal, código, ejecución de cambios.
3. **Hermes supervisa** — el orquestador propone, Hermes (vos) aprueba y aplica. Nada se
   ejecuta de forma autónoma sin tu mando.

## Estructura

```
scripts/agent_bridge/
├── README.md                 # este archivo
├── config.yaml               # modelos, endpoints, claves (referencias a .env)
├── orchestrator.py           # orquestador central (dispatch + bus + memoria)
├── bus/
│   └── message_bus.py        # bus de mensajes (archivos JSON en bus/inbox|outbox)
├── memory/
│   ├── context_builder.py    # arma el contexto común (.cursorrules + decisiones + Graphify)
│   ├── decisions.json        # decisiones previas (ej. Docker en ZimaOS)
│   └── graphify_query.py     # consulta el grafo Graphify/Kai Vault
├── agents/
│   ├── luna_agent.py         # especialista visión (OpenRouter GPT-5.6-Luna)
│   ├── deepseek_agent.py     # especialista lógica/SQL
│   └── codex_agent.py        # especialista terminal/código
└── vision/
    ├── capturar.py           # captura screenshots PWAs/Flutter (Playwright)
    ├── contrast_verify.py    # verificación MATEMÁTICA de contraste WCAG (script propio)
    └── luna_audit.py         # flujo: captura → Luna → contraste → instrucciones
```

## Flujos

### Flujo de Visión (Luna)
```bash
# 1. Captura las pantallas (PWA light/dark + Flutter)
python3 vision/capturar.py --targets pwa-login,rider,driver

# 2. Luna audita + verifica contraste matemático
python3 vision/luna_audit.py --screenshots /tmp/screenshots/

# 3. Salida: instrucciones de corrección → Hermes las aplica
```

### Flujo de Memoria (Graphify + Vault)
```bash
python3 memory/context_builder.py --consulta "arquitectura de mapas H3"
# → devuelve .cursorrules + decisiones + nodos del grafo relacionados
```

### Orquestación general
```bash
python3 orchestrator.py --tarea "auditar contraste de la PWA" --agentes luna,deepseek
```

## Reglas duras

- **Cero alucinaciones en contraste**: Luna NO calcula ratios WCAG de forma fiable
  (alucina). SIEMPRE se usa `vision/contrast_verify.py` (cálculo matemático propio).
- **Verde agua `#64DEB2`**: texto sobre botón verde SIEMPRE oscuro `#0F172A` (10.74:1),
  nunca blanco (1.66:1). Texto/links sobre claro → `#0E7C5E`.
- **Docker NO funciona en ZimaOS** (seccomp, sin CAP_SYS_ADMIN). Servicios NATIVOS en
  ZimaOS; Docker solo en Oracle.
- **100% español** en código, comentarios y respuestas.
