-- =====================================================================
-- 04: Consultas del tablero
-- Una vista con los datos de cada ticket ya calculados y una función
-- por cada pantalla. La página llama a las funciones con db.rpc().
-- =====================================================================

-- Vista base: cada ticket con los nombres de sus tablas relacionadas
-- y los cálculos que usan todas las consultas.
--   horas:      si está resuelto, lo que tardó en resolverse;
--               si está pendiente, el tiempo que lleva abierto.
--   dentro_sla: true/false para los resueltos, null para los pendientes.
-- security_invoker hace que la vista respete las políticas RLS de las tablas.
create or replace view v_tickets with (security_invoker = true) as
select
  t.id,
  t.titulo,
  t.solicitante,
  t.estado,
  t.fecha_creacion,
  t.fecha_resolucion,
  t.departamento_id,
  d.nombre                                   as departamento,
  t.categoria_id,
  c.nombre                                   as categoria,
  t.prioridad_id,
  p.nombre                                   as prioridad,
  p.orden                                    as prioridad_orden,
  p.sla_horas,
  t.tecnico_id,
  te.nombre || ' ' || te.apellido            as tecnico,
  t.estado in ('Abierto', 'En progreso')     as pendiente,
  round((extract(epoch from coalesce(t.fecha_resolucion, now()) - t.fecha_creacion) / 3600)::numeric, 1) as horas,
  case when t.fecha_resolucion is not null
       then t.fecha_resolucion - t.fecha_creacion <= p.sla_horas * interval '1 hour'
  end                                        as dentro_sla
from tickets t
join departamentos d on d.id = t.departamento_id
join categorias    c on c.id = t.categoria_id
join prioridades   p on p.id = t.prioridad_id
left join tecnicos te on te.id = t.tecnico_id;

-- ---------------------------------------------------------------------
-- Indicadores generales (tarjetas de la pantalla principal)
-- ---------------------------------------------------------------------
create or replace function resumen_general()
returns table (tickets bigint, pendientes bigint, pct_sla numeric, horas_promedio numeric)
language sql stable
set search_path = public
as $$
  select
    count(*),
    count(*) filter (where pendiente),
    round(100.0 * count(*) filter (where dentro_sla)
          / nullif(count(*) filter (where dentro_sla is not null), 0)),
    round(avg(horas) filter (where not pendiente), 1)
  from v_tickets;
$$;

-- ---------------------------------------------------------------------
-- NIVEL 1: un resumen por departamento
-- ---------------------------------------------------------------------
create or replace function resumen_departamentos()
returns table (id integer, nombre varchar, tickets bigint, pendientes bigint,
               pct_sla numeric, horas_promedio numeric)
language sql stable
set search_path = public
as $$
  select
    d.id,
    d.nombre,
    count(v.id),
    count(v.id) filter (where v.pendiente),
    round(100.0 * count(v.id) filter (where v.dentro_sla)
          / nullif(count(v.id) filter (where v.dentro_sla is not null), 0)),
    round(avg(v.horas) filter (where not v.pendiente), 1)
  from departamentos d
  left join v_tickets v on v.departamento_id = d.id
  group by d.id, d.nombre
  order by d.nombre;
$$;

-- ---------------------------------------------------------------------
-- NIVEL 2: las categorías de un departamento
-- Se parte de categorias con LEFT JOIN para que aparezcan todas,
-- aunque el departamento no tenga tickets de alguna.
-- ---------------------------------------------------------------------
create or replace function resumen_categorias(p_departamento integer)
returns table (id integer, nombre varchar, tickets bigint, pendientes bigint,
               pct_sla numeric, horas_promedio numeric)
language sql stable
set search_path = public
as $$
  select
    c.id,
    c.nombre,
    count(v.id),
    count(v.id) filter (where v.pendiente),
    round(100.0 * count(v.id) filter (where v.dentro_sla)
          / nullif(count(v.id) filter (where v.dentro_sla is not null), 0)),
    round(avg(v.horas) filter (where not v.pendiente), 1)
  from categorias c
  left join v_tickets v on v.categoria_id = c.id
                       and v.departamento_id = p_departamento
  group by c.id, c.nombre
  order by c.nombre;
$$;

-- ---------------------------------------------------------------------
-- NIVEL 3: los tickets de una categoría dentro de un departamento
-- Primero los pendientes, después por urgencia y los más nuevos arriba.
-- ---------------------------------------------------------------------
create or replace function detalle_tickets(p_departamento integer, p_categoria integer)
returns table (id integer, titulo varchar, solicitante varchar, prioridad varchar,
               tecnico text, estado varchar, fecha_creacion timestamptz,
               horas numeric, sla_horas integer, pendiente boolean, dentro_sla boolean)
language sql stable
set search_path = public
as $$
  select v.id, v.titulo, v.solicitante, v.prioridad, v.tecnico, v.estado,
         v.fecha_creacion, v.horas, v.sla_horas, v.pendiente, v.dentro_sla
  from v_tickets v
  where v.departamento_id = p_departamento
    and v.categoria_id = p_categoria
  order by v.pendiente desc, v.prioridad_orden, v.fecha_creacion desc;
$$;

-- ---------------------------------------------------------------------
-- Vista de técnicos: carga de trabajo y cumplimiento
-- ---------------------------------------------------------------------
create or replace function resumen_tecnicos()
returns table (id integer, nombre text, especialidad varchar, asignados bigint,
               pendientes bigint, pct_sla numeric, horas_promedio numeric)
language sql stable
set search_path = public
as $$
  select
    te.id,
    te.nombre || ' ' || te.apellido,
    c.nombre,
    count(v.id),
    count(v.id) filter (where v.pendiente),
    round(100.0 * count(v.id) filter (where v.dentro_sla)
          / nullif(count(v.id) filter (where v.dentro_sla is not null), 0)),
    round(avg(v.horas) filter (where not v.pendiente), 1)
  from tecnicos te
  join categorias c on c.id = te.especialidad
  left join v_tickets v on v.tecnico_id = te.id
  where te.activo
  group by te.id, te.nombre, te.apellido, c.nombre
  order by count(v.id) desc;
$$;

-- Tickets pendientes sin técnico asignado (alerta de la pantalla principal)
create or replace function tickets_sin_tecnico()
returns table (id integer, titulo varchar, departamento varchar, prioridad varchar,
               horas numeric, sla_horas integer)
language sql stable
set search_path = public
as $$
  select v.id, v.titulo, v.departamento, v.prioridad, v.horas, v.sla_horas
  from v_tickets v
  where v.tecnico_id is null and v.pendiente
  order by v.prioridad_orden, v.fecha_creacion;
$$;

grant select on v_tickets to anon, authenticated;
grant execute on function resumen_general()                      to anon, authenticated;
grant execute on function resumen_departamentos()                to anon, authenticated;
grant execute on function resumen_categorias(integer)            to anon, authenticated;
grant execute on function detalle_tickets(integer, integer)      to anon, authenticated;
grant execute on function resumen_tecnicos()                     to anon, authenticated;
grant execute on function tickets_sin_tecnico()                  to anon, authenticated;
