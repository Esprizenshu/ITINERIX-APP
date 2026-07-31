# Itinerix — contexto del proyecto

SaaS multi-tenant para agentes/agencias de viajes: cotizaciones profesionales
(vuelos, hoteles, servicios, descuentos, multi-moneda), confirmaciones y
vouchers, exportables a PDF o como link compartible.

No confundir con la landing de marketing (itinerix.online, WordPress) — este
repo es la aplicación SaaS nueva e independiente, para vivir en
`app.itinerix.online`. La landing no se toca desde aquí.

## Modelo de negocio

Dos modelos de cobro **coexistiendo** sobre la misma agencia, no uno u otro:

1. **Suscripción mensual por planes** (Básico $29 / Pro $79 / Enterprise $199),
   con límites de uso: clientes activos y cotizaciones/mes (Básico), sin
   límite en Pro/Enterprise.
2. **Créditos prepago**: saldo que se debita por cotización generada, ya sea
   como complemento cuando se excede el cupo del plan, o como modelo
   standalone para quien no quiere suscribirse.

Un freelancer es una **agencia de una sola persona** (`agencias.tipo =
'freelancer'`), no un caso sin tenant. Puede operar con plan de suscripción,
con créditos prepago, o ambos — igual que cualquier agencia.

Reglas de negocio ya decididas (ver historial de la conversación de diseño
para el razonamiento completo):

- **Límite de clientes activos**: se aplica en tiempo real vía trigger de
  Postgres al insertar en `clientes` (tabla aún no creada — Fase 1), no solo
  validación en la app. Si la agencia no tiene plan de suscripción activo
  (solo créditos), no aplica límite de clientes.
- **Consumo mensual vs créditos**: al generar una cotización, primero se
  intenta cubrir con el cupo del plan activo (`max_cotizaciones_mes`); si se
  excede o no hay plan, se debita del saldo prepago; si no alcanza el saldo,
  se bloquea y se sugiere recarga/upgrade. Esto se implementa como una
  función transaccional (RPC), no como lógica dispersa en el cliente — el
  sistema WordPress anterior tenía esta lógica de débito construida pero
  nunca conectada a la UI real, es el error a no repetir.
- **Términos legales**: editables por `admin_agencia` (solo su propia
  agencia) y `super_admin` (cualquier agencia). `asesor` y `freelancer` solo
  lectura de los suyos — ojo, esto es distinto a lo que se decidió
  originalmente para freelancer en la conversación de diseño (ahí se asumió
  que freelancer sí podía editar los propios); la instrucción explícita del
  usuario fue "el rol asesor NO tiene permiso, solo super_admin y
  admin_agencia", así que freelancer también queda de solo lectura salvo que
  se indique lo contrario.
- **Vuelos**: campos estructurados (aerolínea, número de vuelo, origen,
  destino, fecha, hora salida, hora llegada, escalas + detalle de escalas en
  texto libre, notas libres como escape hatch). Decisión explícita para
  soportar en el futuro (Fase 7) autocompletado por visión (Claude leyendo
  una captura de pantalla de la aerolínea) — el prototipo original solo
  tenía una cadena de texto libre "ruta", no lo repliques así.

## Decisiones de arquitectura

- **Next.js 14.2.35** (App Router, TypeScript estricto), no 15/16 —
  decisión explícita del usuario para mantener código confiable con
  convenciones bien conocidas, no la última versión.
- **Supabase** (Postgres + Auth + Storage). Proyecto real ya creado por el
  usuario ("ITINERIX", ref `nakcrvczframsmznytpb`), credenciales en
  `.env.local` (gitignored, nunca commitear).
- **`reference/` está gitignored**, a propósito: contiene el prototipo HTML
  original y los plugins WordPress originales con datos reales sensibles
  (cuenta bancaria de Itinerix SAS, NIT, textos legales de TERA Viajes).
  Sigue existiendo en disco para que cualquier sesión futura la lea como
  especificación funcional, pero nunca se sube a git/GitHub/Vercel.
- Tenant = `agencias`. Un usuario pertenece a exactamente una agencia
  (`profiles.agencia_id`, not null). Aislamiento vía RLS de Postgres, no
  filtros manuales `WHERE agencia_id = ...` en el código de la app.
- Nomenclatura de roles: un único enum canónico
  `freelancer | asesor | admin_agencia | super_admin`, usado igual en DB y
  en la app. El sistema WordPress anterior tenía seis vocabularios de rol
  incompatibles entre archivos — evitar ese patrón a toda costa.
- RLS evita recursión usando funciones `security definer`
  (`current_agencia_id()`, `current_user_role()`) en vez de subconsultas
  directas a `profiles` dentro de las policies de `profiles`.
- Convención de nombres: entidades y columnas de dominio en **español**
  (agencias, cotizaciones, precio_adulto...), siguiendo el vocabulario ya
  usado en la especificación funcional. Código (variables TS, nombres de
  archivo, componentes) en inglés/convención estándar de Next.js.
- Idioma de interfaz (ES/EN/PT) vía `next-intl`, sin prefijo de locale en la
  URL (no hace falta SEO multi-idioma, es una app autenticada) — resuelto
  desde `profiles.idioma_preferido` o cookie. Aún no instalado (llega con la
  primera pantalla que lo necesite).
- Fotos de hotel y comprobantes de recarga van a Supabase Storage, no como
  base64 en el cliente (así lo hacía el prototipo original, no replicar).

## Esquema de base de datos vigente

Ver `supabase/migrations/` como fuente de verdad. Migraciones aplicadas:

- `20260731000000_init_agencias_profiles_roles.sql` — tipo `user_role` enum,
  tablas `agencias` (id, tipo, nombre, activo, created_at — solo identidad
  mínima, branding/saldo/facturación se agregan en su fase correspondiente)
  y `profiles` (id → auth.users, agencia_id, role, nombre, activo), RLS +
  funciones helper. No incluye políticas de INSERT: el alta de
  agencia+profile la hace el flujo de registro server-side con
  `service_role` (aún no construido).

El resto del esquema completo (clientes, cotizaciones + planes/vuelos/
hoteles/servicios, planes_suscripcion, agencia_suscripciones,
transacciones_creditos, solicitudes_recarga, agencia_terminos_legales) fue
diseñado y aprobado por el usuario mientras se conversaba este historial,
pero **todavía no está migrado** — se crea fase por fase según el plan de
abajo, no todo de una vez.

`src/types/database.types.ts` está escrito a mano para reflejar la
migración actual. Reemplazar por la salida real de
`supabase gen types typescript --linked` en cuanto el proyecto quede
enlazado al Supabase CLI (pendiente: requiere un access token personal +
password de la base, no solo las API keys que ya están en `.env.local`).

## Estado de las fases

- [x] **Fase 0** — scaffold Next.js 14, Git inicializado, conexión a
      Supabase, tablas base (`agencias`, `profiles`) + 4 roles, clientes
      Supabase (browser/server/admin) + middleware de sesión.
- [ ] **Fase 1** — CRUD de cotizaciones con borradores (clientes,
      cotizaciones, cotizacion_planes, vuelos, hoteles, servicios).
- [ ] **Fase 2** — PDF server-side + link compartible.
- [ ] **Fase 3** — multi-tenancy con branding + términos legales
      versionados.
- [ ] **Fase 4** — modelo de cobro combinado (planes + créditos
      coexistiendo).
- [ ] **Fase 5** — Stripe (suscripciones).
- [ ] **Fase 6** — confirmaciones de itinerario y vouchers.
- [ ] **Fase 7** — dominios personalizados / white-label. Incluye la visión
      por IA para autocompletar vuelos desde captura de pantalla.

## Notas de entorno (esta máquina)

Node.js está instalado en `C:\Program Files\nodejs` pero no siempre aparece
en el PATH de sesiones de shell ya abiertas (quedó agregado al PATH de
Máquina después de que algunas terminales ya habían arrancado). Si
`node`/`npm` no se reconocen, anteponer:
`export PATH="/c/Program Files/nodejs:$PATH"` (bash) o
`$env:Path = "C:\Program Files\nodejs;" + $env:Path` (PowerShell) al comando.
