#!/usr/bin/env python3
"""
FASE 5 — Verificación de RLS Policies y Triggers de Auditoría
"""
import psycopg2
import json

DSN = "postgresql://postgres:TU_PASSWORD_DB@db.TU_PROYECTO.supabase.co:5432/postgres"

def main():
    conn = psycopg2.connect(DSN)
    conn.autocommit = True
    cur = conn.cursor()

    results = []

    # ═══ 1. ALL RLS POLICIES ═══
    cur.execute("""
        SELECT tablename, policyname, cmd, qual IS NOT NULL as has_using,
               with_check IS NOT NULL as has_check
        FROM pg_policies
        WHERE schemaname = 'public'
        ORDER BY tablename, cmd
    """)
    all_policies = cur.fetchall()
    results.append(f"✅ Políticas RLS totales: {len(all_policies)}")

    # ═══ 2. Core tables RLS check ═══
    core_tables = [
        'b2b_empresas', 'b2b_consumo_api', 'b2b_licitaciones', 'b2b_ofertas',
        'franquicia_config_auditoria', 'franquicias', 'cierres_semanales',
        'viajes', 'perfiles', 'vehiculo_documentos',
    ]
    for tbl in core_tables:
        cur.execute(f"""
            SELECT relrowsecurity FROM pg_class
            WHERE oid='public.{tbl}'::regclass
        """)
        row = cur.fetchone()
        if row and row[0]:
            cur.execute(f"""
                SELECT count(*) FROM pg_policies
                WHERE schemaname='public' AND tablename='{tbl}'
            """)
            np = cur.fetchone()[0]
            results.append(f"  ✅ {tbl}: RLS activo, {np} políticas")
        else:
            results.append(f"  ❌ {tbl}: RLS NO ACTIVO")

    # ═══ 3. Audit trigger check ═══
    cur.execute("""
        SELECT tgname, tgrelid::regclass
        FROM pg_trigger
        WHERE tgname LIKE '%audit%' AND tgrelid::regclass::text LIKE '%franquicia%'
    """)
    audit_triggers = cur.fetchall()
    if audit_triggers:
        for at in audit_triggers:
            results.append(f"  ✅ Trigger auditoría: {at[0]} ON {at[1]}")
    else:
        results.append("  ⚠️ No se encontraron triggers de auditoría")

    # ═══ 4. Constraints check ═══
    critical_constraints = [
        ('b2b_empresas', 'b2b_empresas_frecuencia_check'),
        ('cierres_semanales', 'cierres_semanales_flujo_tipo_check'),
        ('b2b_consumo_api', 'b2b_consumo_api_cierre_fk'),
    ]
    for tbl, conname in critical_constraints:
        cur.execute(f"""
            SELECT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname='{conname}' AND conrelid='public.{tbl}'::regclass
            )
        """)
        if cur.fetchone()[0]:
            results.append(f"  ✅ {tbl}.{conname}: activo")
        else:
            results.append(f"  ❌ {tbl}.{conname}: NO ENCONTRADO")

    # ═══ 5. Data integrity check under load ═══
    # Check if any orphaned records exist
    cur.execute("SELECT count(*) FROM b2b_consumo_api WHERE empresa_id IS NULL")
    orphan_b2b = cur.fetchone()[0]
    if orphan_b2b == 0:
        results.append(f"  ✅ b2b_consumo_api: 0 registros huérfanos")
    else:
        results.append(f"  ⚠️ b2b_consumo_api: {orphan_b2b} registros sin empresa_id")

    cur.execute("SELECT count(*) FROM b2b_ofertas WHERE licitacion_id IS NULL")
    orphan_offers = cur.fetchone()[0]
    if orphan_offers == 0:
        results.append(f"  ✅ b2b_ofertas: 0 registros huérfanos")
    else:
        results.append(f"  ⚠️ b2b_ofertas: {orphan_offers} registros sin licitacion_id")

    # ═══ 6. Notifications table check ═══
    cur.execute("SELECT count(*) FROM notificaciones_app")
    notif_count = cur.fetchone()[0]
    results.append(f"  📬 notificaciones_app: {notif_count} notificaciones en bandeja")

    # ═══ 7. Print ═══
    print("=" * 60)
    print("FASE 5 — VERIFICACIÓN RLS Y AUDITORÍA")
    print("=" * 60)
    for r in results:
        print(r)

    passed = sum(1 for r in results if '✅' in r)
    failed = sum(1 for r in results if '❌' in r)
    print(f"\n{'='*60}")
    print(f"Resultado: {passed} OK, {failed} fallas, {len(results)} verificaciones")
    print("=" * 60)

    cur.close()
    conn.close()
    return passed, failed

if __name__ == "__main__":
    main()
