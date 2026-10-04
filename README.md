# Tablero de Tickets de Soporte — TP Bases de Datos Aplicada

Dashboard de la mesa de ayuda de una empresa: tickets por departamento, categoría y técnico,
con drill down de 3 niveles y semáforo de cumplimiento de SLA.

**Tecnologías:** HTML + CSS + JavaScript · Supabase (PostgreSQL) · supabase-js · pgcrypto (bcrypt)

## Estructura

| Archivo | Qué es |
|---|---|
| `index.html` + `js/login.js` | Login (valida contra la tabla `usuarios` con la función SQL `login()`) |
| `dashboard.html` + `js/prototipo.js` | Prototipo del tablero (datos de ejemplo, navegación entre niveles) |
| `js/config.js` | URL y clave pública de Supabase |
| `js/sesion.js` | Guarda la sesión y protege el tablero |
| `css/estilos.css` | Estilos |
| `sql/01_esquema.sql` | Tablas, relaciones y seguridad (RLS) |
| `sql/02_login.sql` | Función `login()` con bcrypt |
| `sql/03_datos.sql` | INSERT de datos iniciales y usuario de prueba |
| `docs/entrega1.html` | Documento de la 1ª entrega (descripción + modelo canónico). Ctrl+P → PDF |

## Cómo abrirlo

Opción 1: doble clic en `index.html`.

Opción 2 (servidor local, recomendado):

```
powershell -ExecutionPolicy Bypass -File servidor.ps1
```

y abrir http://localhost:5500

El usuario de prueba está en `sql/03_datos.sql`.
