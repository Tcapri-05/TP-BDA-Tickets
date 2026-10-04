// Si ya hay sesión iniciada, ir directo al tablero.
if (obtenerSesion()) {
  window.location.href = "dashboard.html";
}

const formulario = document.getElementById("form-login");
const mensajeError = document.getElementById("error");
const boton = document.getElementById("btn-ingresar");

formulario.addEventListener("submit", async (evento) => {
  evento.preventDefault();
  mensajeError.textContent = "";

  const usuario = document.getElementById("usuario").value.trim();
  const password = document.getElementById("password").value;

  if (!usuario || !password) {
    mensajeError.textContent = "Completá usuario y contraseña.";
    return;
  }

  boton.disabled = true;
  boton.textContent = "Verificando...";

  // Llama a la función login() de la base de datos.
  // La base compara la contraseña con el hash bcrypt guardado.
  const { data, error } = await db.rpc("login", {
    p_usuario: usuario,
    p_password: password,
  });

  boton.disabled = false;
  boton.textContent = "Ingresar";

  if (error) {
    mensajeError.textContent = "No se pudo conectar con la base de datos.";
    console.error(error);
    return;
  }

  // Si no devolvió ninguna fila, las credenciales son incorrectas.
  if (data.length === 0) {
    mensajeError.textContent = "Usuario o contraseña incorrectos.";
    return;
  }

  guardarSesion(data[0]);
  window.location.href = "dashboard.html";
});
