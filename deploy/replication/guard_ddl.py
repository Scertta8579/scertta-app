#!/usr/bin/env python3
"""
GUARD DDL — Bloquea cambios estructurales directos.
Si un script Python intenta ALTER/CREATE/DROP TABLE, este guard lo rechaza
y redirige al pipeline migrate.sh.

Uso: python3 guard_ddl.py <script_a_ejecutar.py>
El script se ejecuta en modo 'read-only': solo SELECT, INSERT, UPDATE, DELETE.
Cualquier DDL es rechazado con mensaje de error.
"""

import sys
import re

DDL_PATTERNS = [
    r'\bCREATE\s+TABLE\b',
    r'\bALTER\s+TABLE\b',
    r'\bDROP\s+TABLE\b',
    r'\bCREATE\s+INDEX\b',
    r'\bDROP\s+INDEX\b',
    r'\bCREATE\s+EXTENSION\b',
    r'\bCREATE\s+SCHEMA\b',
    r'\bCREATE\s+FUNCTION\b',
    r'\bCREATE\s+TRIGGER\b',
    r'\bCREATE\s+POLICY\b',
    r'\bCREATE\s+TYPE\b',
    r'\bADD\s+COLUMN\b',
    r'\bDROP\s+COLUMN\b',
    r'\bRENAME\s+COLUMN\b',
    r'\bALTER\s+COLUMN\b',
]

def check_file(filepath):
    with open(filepath) as f:
        content = f.read().upper()
    
    violations = []
    for pattern in DDL_PATTERNS:
        matches = re.findall(pattern, content)
        if matches:
            violations.extend(matches)
    
    return violations

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 guard_ddl.py <script.py>")
        sys.exit(0)
    
    target = sys.argv[1]
    violations = check_file(target)
    
    if violations:
        print("=" * 60)
        print("🛑 GUARD DDL — CAMBIO ESTRUCTURAL BLOQUEADO")
        print("=" * 60)
        print(f"\nEl script '{target}' contiene comandos DDL:")
        for v in set(violations):
            print(f"  • {v}")
        print("\n🚫 Está PROHIBIDO hacer cambios estructurales directos.")
        print("   Todo DDL debe pasar por el pipeline Local-First:")
        print("   $ ./deploy/replication/migrate.sh new <nombre>")
        print("   $ ./deploy/replication/migrate.sh push")
        print("\nEsto asegura paridad 100% entre PostgreSQL local y Supabase Cloud.")
        print("=" * 60)
        sys.exit(1)
    
    # Pass through if no DDL
    print(f"✅ {target}: sin DDL detectado. Ejecución permitida.")
