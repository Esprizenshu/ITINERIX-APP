-- Fase 0: estructura de tablas base e identidad multi-tenant.
-- Entidades de negocio completas (clientes, cotizaciones, planes de
-- suscripcion, saldo de creditos, terminos legales...) se agregan en
-- migraciones posteriores, fase por fase.

create extension if not exists pgcrypto;

create type public.user_role as enum (
  'freelancer',
  'asesor',
  'admin_agencia',
  'super_admin'
);

-- Una agencia es el tenant. Un freelancer es una agencia de una sola
-- persona (tipo='freelancer'), no un caso especial sin agencia.
create table public.agencias (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('agencia', 'freelancer')),
  nombre text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

-- Un usuario pertenece a exactamente una agencia.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  agencia_id uuid not null references public.agencias (id) on delete restrict,
  role public.user_role not null,
  nombre text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create index profiles_agencia_id_idx on public.profiles (agencia_id);

alter table public.agencias enable row level security;
alter table public.profiles enable row level security;

-- Funciones security definer para leer el rol/agencia del usuario actual
-- sin caer en recursion de RLS al evaluar las policies de abajo.
create or replace function public.current_agencia_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select agencia_id from public.profiles where id = auth.uid();
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql
security definer
stable
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create policy "profiles_select_own_or_super_admin"
  on public.profiles for select
  using (id = auth.uid() or public.current_user_role() = 'super_admin');

create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid());

create policy "agencias_select_own_or_super_admin"
  on public.agencias for select
  using (id = public.current_agencia_id() or public.current_user_role() = 'super_admin');

create policy "agencias_update_admin_or_super_admin"
  on public.agencias for update
  using (
    (id = public.current_agencia_id() and public.current_user_role() in ('admin_agencia', 'freelancer'))
    or public.current_user_role() = 'super_admin'
  );

-- No hay policies de INSERT: el alta de agencia+profile la hace el flujo
-- de registro server-side con el service_role key (bypassa RLS), ya que
-- ese flujo todavia no esta definido (aprobaciones, freelancer vs agencia).
