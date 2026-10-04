-- =====================================================================
-- TP Bases de Datos Aplicada - Tablero de Tickets de Soporte
-- 01: Esquema (tablas, relaciones y restricciones)
-- Motor: PostgreSQL (Supabase)
-- =====================================================================

-- Áreas de la empresa que reportan problemas
create table departamentos (
  id          serial primary key,
  nombre      varchar(60) not null unique,
  responsable varchar(80) not null
);

-- Tipo de problema (Hardware, Software, Redes, etc.)
create table categorias (
  id          serial primary key,
  nombre      varchar(60) not null unique,
  descripcion varchar(200)
);

-- Prioridad del ticket y tiempo máximo de resolución (SLA)
create table prioridades (
  id        serial primary key,
  nombre    varchar(20) not null unique,
  sla_horas integer not null check (sla_horas > 0),
  orden     integer not null unique
);

-- Personal de soporte que resuelve los tickets
create table tecnicos (
  id           serial primary key,
  nombre       varchar(50) not null,
  apellido     varchar(50) not null,
  email        varchar(100) not null unique,
  especialidad integer not null references categorias(id),
  activo       boolean not null default true
);

-- Entidad principal: cada problema reportado
create table tickets (
  id               serial primary key,
  titulo           varchar(120) not null,
  descripcion      text,
  solicitante      varchar(80) not null,
  departamento_id  integer not null references departamentos(id),
  categoria_id     integer not null references categorias(id),
  prioridad_id     integer not null references prioridades(id),
  tecnico_id       integer references tecnicos(id),   -- null = sin asignar
  estado           varchar(20) not null default 'Abierto'
                   check (estado in ('Abierto', 'En progreso', 'Resuelto', 'Cerrado')),
  fecha_creacion   timestamptz not null default now(),
  fecha_resolucion timestamptz,
  check (fecha_resolucion is null or fecha_resolucion >= fecha_creacion)
);

create index idx_tickets_departamento on tickets(departamento_id);
create index idx_tickets_categoria    on tickets(categoria_id);
create index idx_tickets_tecnico      on tickets(tecnico_id);
create index idx_tickets_estado       on tickets(estado);

-- Usuarios que pueden entrar al tablero (login)
create table usuarios (
  id            serial primary key,
  usuario       varchar(40) not null unique,
  password_hash text not null,          -- nunca se guarda la contraseña en texto plano
  nombre        varchar(80) not null,
  rol           varchar(20) not null default 'analista'
                check (rol in ('admin', 'analista'))
);

-- ---------------------------------------------------------------------
-- Seguridad (Row Level Security)
-- La tabla usuarios queda cerrada: solo se accede mediante la función login().
-- Las tablas del tablero se pueden leer (solo lectura) desde la página.
-- ---------------------------------------------------------------------
alter table usuarios      enable row level security;
alter table departamentos enable row level security;
alter table categorias    enable row level security;
alter table prioridades   enable row level security;
alter table tecnicos      enable row level security;
alter table tickets       enable row level security;

create policy "lectura departamentos" on departamentos for select using (true);
create policy "lectura categorias"    on categorias    for select using (true);
create policy "lectura prioridades"   on prioridades   for select using (true);
create policy "lectura tecnicos"      on tecnicos      for select using (true);
create policy "lectura tickets"       on tickets       for select using (true);
