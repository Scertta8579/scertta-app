#!/bin/bash

# Script para desplegar Edge Functions de Supabase
# Uso: ./deploy.sh [nombre-funcion]

set -e

echo "🚀 Desplegando Edge Functions de Scertta"
echo "========================================="

# Verificar que Supabase CLI esté instalado
if ! command -v supabase &> /dev/null; then
    echo "❌ Error: Supabase CLI no está instalado"
    echo "Instala con: npm install -g supabase"
    exit 1
fi

# Verificar que estemos logueados
if ! supabase projects list &> /dev/null; then
    echo "❌ Error: No estás logueado en Supabase"
    echo "Ejecuta: supabase login"
    exit 1
fi

# Si se proporciona un nombre de función, desplegar solo esa
if [ -n "$1" ]; then
    echo "📦 Desplegando función: $1"
    supabase functions deploy "$1"
    echo "✅ Función $1 desplegada exitosamente"
else
    # Desplegar todas las funciones
    echo "📦 Desplegando todas las funciones..."
    
    for dir in */; do
        func_name="${dir%/}"
        if [ -f "$func_name/index.ts" ]; then
            echo "  → Desplegando $func_name..."
            supabase functions deploy "$func_name"
        fi
    done
    
    echo "✅ Todas las funciones desplegadas exitosamente"
fi

echo ""
echo "📊 Ver logs:"
echo "supabase functions logs enviar-bienvenida --tail"
echo ""
echo "🧪 Probar función:"
echo "curl -X POST https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida \\"
echo "  -H 'Authorization: Bearer TU_ANON_KEY' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\": \"test@ejemplo.com\", \"nombre\": \"Test\"}'"
