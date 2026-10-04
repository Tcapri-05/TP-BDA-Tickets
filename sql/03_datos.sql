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
select setseed(0.42);

insert into tickets (titulo, solicitante, departamento_id, categoria_id, prioridad_id,
                     tecnico_id, estado, fecha_creacion, fecha_resolucion)
select
  t.titulo,
  t.solicitante,
  t.departamento_id,
  t.categoria_id,
  t.prioridad_id,
  case when t.estado = 'Abierto' and random() < 0.5 then null else t.tecnico_id end,
  t.estado,
  t.fecha_creacion,
  case when t.estado in ('Resuelto', 'Cerrado')
       then least(now(), t.fecha_creacion + (p.sla_horas * (0.2 + random() * 1.3)) * interval '1 hour')
  end
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
    1 + floor(random() * 6)::int                                     as tecnico_id,
    case
      when f.dias > 10 then (array['Resuelto', 'Cerrado', 'Cerrado'])[1 + floor(random() * 3)::int]
      else (array['Abierto', 'En progreso', 'Resuelto', 'Abierto'])[1 + floor(random() * 4)::int]
    end                                                              as estado,
    now() - f.dias * interval '1 day' - floor(random() * 24) * interval '1 hour' as fecha_creacion
  from generate_series(1, 200) g
  cross join lateral (select 1 + floor(random() * 5)::int as cat, g as g1) c
  cross join lateral (select random() as p, g as g2) r
  cross join lateral (select floor(random() * 90)::int as dias, g as g3) f
) t
join prioridades p on p.id = t.prioridad_id;
