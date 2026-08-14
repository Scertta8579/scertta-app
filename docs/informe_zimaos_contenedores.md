# Informe: ZimaOS y la ejecución de contenedores sin restricción de namespaces

> Fecha: 14 de agosto de 2026. Autor: Hermes (supervisado por Andres).
> Objetivo: explicar por qué Docker no corre en ZimaOS y qué se necesita para desbloquearlo.

## 1. Diagnóstico (verificado con evidencia)

ZimaOS corre en un entorno con restricciones de seguridad que bloquean la ejecución
nativa de contenedores:

| Prueba | Resultado | Conclusión |
|--------|-----------|------------|
| `unshare --mount` / `unshare --user` | `EPERM` (Operation not permitted) | No se pueden crear namespaces |
| `CapEff` (capacidades efectivas) | sin `CAP_SYS_ADMIN` | No se pueden montar filesystems ni namespaces |
| Seccomp | activo (`2`, 1 filtro) | El kernel filtra las syscalls de namespace |
| `/dev/fuse` | no existe | `fuse-overlayfs` (alternativa en espacio de usuario) no funciona |
| `repositories.json` de Docker | vacío | Docker jamás pudo extraer una imagen |

**Causa raíz**: ZimaOS (y su base) se ejecuta como un entorno *contenedorizado o
restringido* donde el proceso raíz NO tiene las capacidades completas del kernel
(`CAP_SYS_ADMIN`), y seccomp bloquea las syscalls de creación de namespaces
(`unshare`, `clone` con flags de namespace). Docker necesita ambas cosas para
desempaquetar imágenes y aislar contenedores.

Por eso el patrón correcto del proyecto es: **servicios NATIVOS en ZimaOS
(Valhalla, PostgreSQL, Caddy, Nominatim vía binario) y Docker solo en Oracle.**

## 2. Opciones para desbloquear contenedores nativos

### Opción A — ZimaOS Plus (o reconfigurar ZimaOS)
- **Qué aporta**: ZimaOS Plus desbloquea funciones de virtualización más profundas,
  pero **depende** de que el anfitrión (Asus) permita pasar las capacidades del kernel.
- **Requisito técnico**: el kernel del host debe exponer `CAP_SYS_ADMIN` y permitir
  `unshare`. Si ZimaOS corre *dentro* de un contenedor LXC/Docker del propio Asus,
  la restricción está en el anfitrión, no en ZimaOS.
- **Verificación previa**: confirmar en el BIOS/UEFI del Asus que la virtualización
  (VT-x/AMD-V) y los namespaces no estén limitados.
- **Riesgo**: bajo impacto si ya se usa ZimaOS; alto si el Asus no expone el kernel.

### Opción B — Proxmox VE (recomendada para contenedores reales)
- **Qué es**: hipervisor completo (KVM + LXC) basado en Debian.
- **Por qué funciona**: Proxmox corre **directamente sobre el hardware** (bare-metal)
  con acceso total al kernel → `CAP_SYS_ADMIN`, namespaces, overlayfs y FUSE están
  disponibles. Docker y los contenedores LXC corren sin restricción.
- **Migración**: 
  1. Instalar Proxmox VE en el Asus (o en una partición aparte).
  2. Pasar los datos (los discos sdb2 de 1TB y el sistema) a un LXC/VM.
  3. Dentro de una VM Debian o un LXC privilegiado, correr Docker normalmente.
- **Costo**: reinstalación del host + migración de datos (~1 día de trabajo).
- **Ventaja clave**: es la solución *definitiva* — habilita Docker, LXC y KVM.

### Opción C — Mantener ZimaOS + mover contenedores a Oracle (estado actual)
- **Qué hacemos hoy**: los servicios con requerimiento de contenedor (Nominatim,
  failover Valhalla) corren en Oracle vía Docker; ZimaOS corre servicios nativos.
- **Ventaja**: cero riesgo, cero downtime, ya en producción.
- **Desventaja**: ZimaOS no ejecuta contenedores; depende de Oracle para eso.

## 3. Recomendación

| Escenario | Recomendación |
|-----------|---------------|
| Querés contenedores en el servidor local HOY sin riesgo | **Opción C** (actual) |
| Querés contenedores nativos en el Asus a mediano plazo | **Opción B (Proxmox VE)** |
| Probá primero si ZimaOS Plus lo habilita (mínimo esfuerzo) | **Opción A**, verificando el kernel del Asus |

**Conclusión**: la restricción de namespaces es del entorno (seccomp + falta de
`CAP_SYS_ADMIN`), no de un archivo de configuración. Solo se resuelve corriendo el
sistema sobre un kernel con acceso completo — Proxmox VE (bare-metal) es la vía
definitiva. Mientras tanto, la arquitectura híbrida ZimaOS-nativo + Oracle-Docker
cubre el 100% de los requerimientos sin tocar el host.
