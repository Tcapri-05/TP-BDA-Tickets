// Manejo simple de la sesión en el navegador.
// Se guarda el usuario logueado en sessionStorage (se borra al cerrar la pestaña).

function guardarSesion(usuario) {
  sessionStorage.setItem("usuario", JSON.stringify(usuario));
}

function obtenerSesion() {
  const dato = sessionStorage.getItem("usuario");
  return dato ? JSON.parse(dato) : null;
}

function cerrarSesion() {
  sessionStorage.removeItem("usuario");
  window.location.href = "index.html";
}

// Se llama al principio de cada página protegida:
// si no hay sesión, vuelve al login.
function exigirSesion() {
  const usuario = obtenerSesion();
  if (!usuario) {
    window.location.href = "index.html";
  }
  return usuario;
}
