-- =====================================================================
-- 02: Login
-- Las contraseñas se guardan con bcrypt (extensión pgcrypto).
-- La página llama a la función login(); la tabla usuarios nunca se expone.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- Devuelve los datos del usuario si usuario y contraseña coinciden.
-- Si no coinciden, no devuelve filas.
create or replace function login(p_usuario text, p_password text)
returns table (id integer, usuario varchar, nombre varchar, rol varchar)
language sql
security definer
set search_path = public, extensions
as $$
  select u.id, u.usuario, u.nombre, u.rol
  from usuarios u
  where u.usuario = p_usuario
    and u.password_hash = crypt(p_password, u.password_hash);
$$;

revoke all on function login(text, text) from public;
grant execute on function login(text, text) to anon, authenticated;
