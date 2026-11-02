-- =====================================================================
-- 03: Datos iniciales (INSERT)
-- =====================================================================

insert into departamentos (nombre, responsable) values
  ('Ventas',          'Laura Gómez'),
  ('Administración',  'Martín Pérez'),
  ('Recursos Humanos','Sofía Fernández'),
  ('Logística',       'Diego Romero'),
  ('Marketing',       'Valentina Ruiz'),
  ('Producción',      'Javier Sosa');

insert into categorias (nombre, descripcion) values
  ('Hardware',         'Fallas de PC, impresoras y periféricos'),
  ('Software',         'Errores o instalación de programas'),
  ('Redes',            'Conectividad, internet, VPN y wifi'),
  ('Accesos y cuentas','Contraseñas, permisos y usuarios bloqueados'),
  ('Correo',           'Problemas con el correo electrónico');

insert into prioridades (nombre, sla_horas, orden) values
  ('Crítica', 4,  1),
  ('Alta',    8,  2),
  ('Media',   24, 3),
  ('Baja',    72, 4);

insert into tecnicos (nombre, apellido, email, especialidad) values
  ('Lucas',   'Martínez', 'lmartinez@empresa.com', 1),
  ('Camila',  'López',    'clopez@empresa.com',    2),
  ('Nicolás', 'García',   'ngarcia@empresa.com',   3),
  ('Julieta', 'Díaz',     'jdiaz@empresa.com',     4),
  ('Tomás',   'Álvarez',  'talvarez@empresa.com',  2),
  ('Micaela', 'Torres',   'mtorres@empresa.com',   3);

-- Usuario de prueba para el login.
-- Usuario: admin   Contraseña: Tickets2026
-- (se guarda encriptada con bcrypt, nunca en texto plano)
insert into usuarios (usuario, password_hash, nombre, rol) values
  ('admin', extensions.crypt('Tickets2026', extensions.gen_salt('bf')), 'Administrador', 'admin');

-- 200 tickets de los últimos 90 días, generados con datos aleatorios
-- (setseed hace que siempre se generen los mismos)
--
-- Reglas para que los datos sean coherentes:
--   * Cada ticket lo atiende un técnico de la especialidad de su categoría.
--     Correo no tiene especialista: lo atienden Camila, Julieta o Tomás.
--   * La probabilidad de resolver dentro del SLA depende del técnico y del
--     departamento (Logística y Producción tienen más demoras).
--     Dentro del SLA: se resuelve entre el 15% y el 95% del plazo.
--     Fuera del SLA:  se resuelve entre el 105% y el 225% del plazo.
--   * Los tickets Abiertos y En progreso son recientes: se crearon hace
--     entre el 10% y el 170% del plazo de su prioridad, así algunos ya vencieron.
select setseed(0.42);

insert into tickets (titulo, solicitante, departamento_id, categoria_id, prioridad_id,
                     tecnico_id, estado, fecha_creacion, fecha_resolucion)
select
  t.titulo,
  t.solicitante,
  t.departamento_id,
  t.categoria_id,
  t.prioridad_id,
  t.tecnico_id,
  t.estado,
  t.fecha_creacion,
  case when t.estado in ('Resuelto', 'Cerrado')
       then t.fecha_creacion + t.sla_horas * interval '1 hour' *
            case when t.azar_sla < (array[0.96, 0.90, 0.70, 0.98, 0.86, 0.78])[t.tecnico_id]
                                 - (array[0.00, 0.05, 0.00, 0.16, 0.02, 0.10])[t.departamento_id]
                 then 0.15 + t.azar_dentro * 0.80
                 else 1.05 + t.azar_fuera * 1.20
            end
  end
from (
  select
    b.titulo,
    b.solicitante,
    b.departamento_id,
    b.categoria_id,
    b.prioridad_id,
    case when b.estado = 'Abierto' and random() < 0.5 then null else b.tecnico_id end as tecnico_id,
    b.estado,
    case when b.estado in ('Resuelto', 'Cerrado') then b.fecha_base
         else now() - p.sla_horas * (0.1 + random() * 1.6) * interval '1 hour'
    end as fecha_creacion,
    p.sla_horas,
    b.azar_sla,
    b.azar_dentro,
    b.azar_fuera
  from (
  select
    (array[
      array['No enciende la PC', 'Impresora atascada', 'Monitor sin imagen', 'Teclado no responde'],
      array['Error al abrir el sistema de facturación', 'Excel se cierra solo', 'Instalar programa de diseño', 'Actualización fallida'],
      array['Sin conexión a internet', 'VPN no conecta', 'Wifi lento en la oficina', 'No accede a carpeta compartida'],
      array['Usuario bloqueado', 'Olvidé mi contraseña', 'Solicitud de permisos al ERP', 'Alta de usuario nuevo'],
      array['No llegan correos', 'Casilla llena', 'Correo marcado como spam', 'Error al enviar adjuntos']
    ])[c.cat][1 + floor(random() * 4)::int]                         as titulo,
    (array['Ana', 'Bruno', 'Carla', 'Diego', 'Elena', 'Facundo', 'Gabriela', 'Hernán'])[1 + floor(random() * 8)::int]
      || ' ' ||
    (array['Silva', 'Ríos', 'Molina', 'Castro', 'Herrera', 'Medina'])[1 + floor(random() * 6)::int] as solicitante,
    1 + floor(random() * 6)::int                                     as departamento_id,
    c.cat                                                            as categoria_id,
    case when r.p < 0.10 then 1 when r.p < 0.35 then 2 when r.p < 0.75 then 3 else 4 end as prioridad_id,
    case c.cat
      when 1 then 1                                                  -- Hardware: Lucas
      when 2 then (array[2, 5])[1 + floor(random() * 2)::int]        -- Software: Camila o Tomás
      when 3 then (array[3, 6])[1 + floor(random() * 2)::int]        -- Redes: Nicolás o Micaela
      when 4 then 4                                                  -- Accesos: Julieta
      else (array[2, 4, 5])[1 + floor(random() * 3)::int]            -- Correo
    end                                                              as tecnico_id,
    case
      when f.dias > 10 then (array['Resuelto', 'Cerrado', 'Cerrado'])[1 + floor(random() * 3)::int]
      else (array['Abierto', 'En progreso', 'Resuelto', 'Abierto'])[1 + floor(random() * 4)::int]
    end                                                              as estado,
    now() - f.dias * interval '1 day' - floor(random() * 24) * interval '1 hour' as fecha_base,
    random()                                                         as azar_sla,
    random()                                                         as azar_dentro,
    random()                                                         as azar_fuera
  from generate_series(1, 200) g
  cross join lateral (select 1 + floor(random() * 5)::int as cat, g as g1) c
  cross join lateral (select random() as p, g as g2) r
  cross join lateral (select floor(random() * 90)::int as dias, g as g3) f
  ) b
  join prioridades p on p.id = b.prioridad_id
) t;
