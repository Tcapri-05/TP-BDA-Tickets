// =====================================================================
// PROTOTIPO DE INTERFAZ (1ª entrega)
// Los datos de abajo son de ejemplo, escritos a mano.
// En la 2ª entrega cada función "datos..." se reemplaza por una consulta SQL.
// =====================================================================

const usuario = exigirSesion();
document.getElementById("nombre-usuario").textContent = usuario ? usuario.nombre : "";

// ---------- Datos de ejemplo ----------
const departamentos = [
  { id: 1, nombre: "Ventas",           tickets: 38, abiertos: 5, sla: 92 },
  { id: 2, nombre: "Administración",   tickets: 31, abiertos: 3, sla: 81 },
  { id: 3, nombre: "Recursos Humanos", tickets: 22, abiertos: 2, sla: 95 },
  { id: 4, nombre: "Logística",        tickets: 35, abiertos: 6, sla: 64 },
  { id: 5, nombre: "Marketing",        tickets: 29, abiertos: 2, sla: 88 },
  { id: 6, nombre: "Producción",       tickets: 45, abiertos: 7, sla: 71 },
];

const categorias = [
  { id: 1, nombre: "Hardware",          tickets: 9, abiertos: 1, sla: 89, promedioHs: 10.5 },
  { id: 2, nombre: "Software",          tickets: 8, abiertos: 2, sla: 75, promedioHs: 14.2 },
  { id: 3, nombre: "Redes",             tickets: 7, abiertos: 2, sla: 57, promedioHs: 21.0 },
  { id: 4, nombre: "Accesos y cuentas", tickets: 6, abiertos: 0, sla: 100, promedioHs: 3.1 },
  { id: 5, nombre: "Correo",            tickets: 5, abiertos: 1, sla: 80, promedioHs: 8.7 },
];

const ticketsEjemplo = [
  { id: 184, titulo: "VPN no conecta",                 prioridad: "Alta",    tecnico: "Nicolás García",  estado: "Abierto",     horas: 11, sla: 8 },
  { id: 176, titulo: "Wifi lento en la oficina",       prioridad: "Media",   tecnico: "Micaela Torres",  estado: "En progreso", horas: 20, sla: 24 },
  { id: 163, titulo: "Sin conexión a internet",        prioridad: "Crítica", tecnico: "Nicolás García",  estado: "Resuelto",    horas: 3,  sla: 4 },
  { id: 151, titulo: "No accede a carpeta compartida", prioridad: "Baja",    tecnico: "Micaela Torres",  estado: "Cerrado",     horas: 30, sla: 72 },
  { id: 142, titulo: "VPN no conecta",                 prioridad: "Alta",    tecnico: "—",               estado: "Abierto",     horas: 2,  sla: 8 },
  { id: 120, titulo: "Wifi lento en la oficina",       prioridad: "Media",   tecnico: "Nicolás García",  estado: "Cerrado",     horas: 31, sla: 24 },
  { id: 97,  titulo: "Sin conexión a internet",        prioridad: "Alta",    tecnico: "Micaela Torres",  estado: "Cerrado",     horas: 6,  sla: 8 },
];

const tecnicos = [
  { nombre: "Lucas Martínez",  especialidad: "Hardware",          asignados: 34, abiertos: 3, sla: 91 },
  { nombre: "Camila López",    especialidad: "Software",          asignados: 30, abiertos: 4, sla: 83 },
  { nombre: "Nicolás García",  especialidad: "Redes",             asignados: 36, abiertos: 6, sla: 66 },
  { nombre: "Julieta Díaz",    especialidad: "Accesos y cuentas", asignados: 28, abiertos: 1, sla: 96 },
  { nombre: "Tomás Álvarez",   especialidad: "Software",          asignados: 31, abiertos: 2, sla: 79 },
  { nombre: "Micaela Torres",  especialidad: "Redes",             asignados: 33, abiertos: 5, sla: 72 },
];

// ---------- Semáforo ----------
// Porcentaje de tickets resueltos dentro del SLA:
//   verde >= 90%  |  amarillo 75% a 89%  |  rojo < 75%
function colorSla(porcentaje) {
  if (porcentaje >= 90) return "verde";
  if (porcentaje >= 75) return "amarillo";
  return "rojo";
}

// Para un ticket: tiempo usado respecto del SLA de su prioridad.
//   verde: usó menos del 75%  |  amarillo: entre 75% y 100%  |  rojo: venció
function colorTicket(t) {
  const uso = t.horas / t.sla;
  if (uso > 1) return "rojo";
  if (uso >= 0.75) return "amarillo";
  return "verde";
}

const luz = (color) => `<span class="luz ${color}"></span>`;

const referenciaSla = `
  <div class="referencia">
    <span>${luz("verde")} Verde: 90% o más de tickets dentro del SLA</span>
    <span>${luz("amarillo")} Amarillo: entre 75% y 89%</span>
    <span>${luz("rojo")} Rojo: menos de 75% (situación crítica)</span>
  </div>`;

function barras(filas) {
  const max = Math.max(...filas.map((f) => f.tickets));
  return `<div class="barras">${filas.map((f) => `
    <div class="barra">
      <span>${f.nombre}</span>
      <div class="pista"><div class="relleno" style="width:${(f.tickets / max) * 100}%"></div></div>
      <strong>${f.tickets}</strong>
    </div>`).join("")}</div>`;
}

// ---------- Navegación (Drill Down / Drill Up) ----------
const vista = document.getElementById("vista");
let deptoActual = null;
let categoriaActual = null;

function migas() {
  let html = `<a onclick="nivel1()">Todos los departamentos</a>`;
  if (deptoActual) html += ` › <a onclick="nivel2(${deptoActual.id})">${deptoActual.nombre}</a>`;
  if (categoriaActual) html += ` › ${categoriaActual.nombre}`;
  return `<div class="migas">${html}</div>`;
}

// NIVEL 1: resumen general por departamento
function nivel1() {
  deptoActual = null;
  categoriaActual = null;
  marcarMenu("nav-resumen");
  const total = departamentos.reduce((s, d) => s + d.tickets, 0);
  const abiertos = departamentos.reduce((s, d) => s + d.abiertos, 0);
  const slaGeneral = 82;

  vista.innerHTML = `
    <div class="encabezado"><h2>Resumen general</h2></div>
    ${migas()}
    <div class="kpis">
      <div class="kpi"><div class="titulo">Tickets (últimos 90 días)</div><div class="valor">${total}</div></div>
      <div class="kpi"><div class="titulo">Abiertos / en progreso</div><div class="valor">${abiertos}</div></div>
      <div class="kpi"><div class="titulo">Resueltos dentro del SLA</div><div class="valor">${luz(colorSla(slaGeneral))} ${slaGeneral}%</div></div>
      <div class="kpi"><div class="titulo">Tiempo promedio de resolución</div><div class="valor">12,4 h</div></div>
    </div>
    <div class="grilla">
      <section class="panel">
        <h3>Tickets por departamento</h3>
        ${barras(departamentos)}
      </section>
      <section class="panel">
        <h3>Cumplimiento de SLA por departamento</h3>
        <div class="tabla-scroll"><table>
          <tr><th>Departamento</th><th>Tickets</th><th>Abiertos</th><th>SLA</th></tr>
          ${departamentos.map((d) => `
            <tr class="clic" onclick="nivel2(${d.id})">
              <td>${d.nombre}</td><td>${d.tickets}</td><td>${d.abiertos}</td>
              <td>${luz(colorSla(d.sla))} ${d.sla}%</td>
            </tr>`).join("")}
        </table></div>
        <p class="ayuda">Hacé clic en un departamento para ver sus categorías.</p>
      </section>
    </div>
    ${referenciaSla}`;
}

// NIVEL 2: categorías de problemas dentro de un departamento
function nivel2(idDepto) {
  deptoActual = departamentos.find((d) => d.id === idDepto);
  categoriaActual = null;

  vista.innerHTML = `
    <div class="encabezado">
      <h2>${deptoActual.nombre}</h2>
      <button class="btn-volver" onclick="nivel1()">← Volver</button>
    </div>
    ${migas()}
    <div class="kpis">
      <div class="kpi"><div class="titulo">Tickets del departamento</div><div class="valor">${deptoActual.tickets}</div></div>
      <div class="kpi"><div class="titulo">Abiertos</div><div class="valor">${deptoActual.abiertos}</div></div>
      <div class="kpi"><div class="titulo">Dentro del SLA</div><div class="valor">${luz(colorSla(deptoActual.sla))} ${deptoActual.sla}%</div></div>
    </div>
    <div class="grilla">
      <section class="panel">
        <h3>Tickets por categoría</h3>
        ${barras(categorias)}
      </section>
      <section class="panel">
        <h3>Detalle por categoría</h3>
        <div class="tabla-scroll"><table>
          <tr><th>Categoría</th><th>Tickets</th><th>Prom. resolución</th><th>SLA</th></tr>
          ${categorias.map((c) => `
            <tr class="clic" onclick="nivel3(${c.id})">
              <td>${c.nombre}</td><td>${c.tickets}</td><td>${c.promedioHs} h</td>
              <td>${luz(colorSla(c.sla))} ${c.sla}%</td>
            </tr>`).join("")}
        </table></div>
        <p class="ayuda">Hacé clic en una categoría para ver los tickets.</p>
      </section>
    </div>
    ${referenciaSla}`;
}

// NIVEL 3: listado de tickets de una categoría en un departamento
function nivel3(idCategoria) {
  categoriaActual = categorias.find((c) => c.id === idCategoria);

  vista.innerHTML = `
    <div class="encabezado">
      <h2>${categoriaActual.nombre} · ${deptoActual.nombre}</h2>
      <button class="btn-volver" onclick="nivel2(${deptoActual.id})">← Volver</button>
    </div>
    ${migas()}
    <section class="panel">
      <h3>Tickets</h3>
      <div class="tabla-scroll"><table>
        <tr><th>#</th><th>Título</th><th>Prioridad</th><th>Técnico</th><th>Estado</th><th>Horas / SLA</th><th></th></tr>
        ${ticketsEjemplo.map((t) => `
          <tr>
            <td>${t.id}</td><td>${t.titulo}</td><td>${t.prioridad}</td><td>${t.tecnico}</td>
            <td><span class="etiqueta">${t.estado}</span></td>
            <td>${t.horas} h / ${t.sla} h</td>
            <td>${luz(colorTicket(t))}</td>
          </tr>`).join("")}
      </table></div>
      <div class="referencia">
        <span>${luz("verde")} Dentro del plazo</span>
        <span>${luz("amarillo")} Usó 75% o más del plazo</span>
        <span>${luz("rojo")} Plazo (SLA) vencido</span>
      </div>
    </section>`;
}

// Vista de técnicos (carga de trabajo)
function vistaTecnicos() {
  marcarMenu("nav-tecnicos");
  vista.innerHTML = `
    <div class="encabezado"><h2>Técnicos</h2></div>
    <p class="migas">Carga de trabajo y cumplimiento de cada técnico</p>
    <section class="panel">
      <div class="tabla-scroll"><table>
        <tr><th>Técnico</th><th>Especialidad</th><th>Asignados</th><th>Abiertos</th><th>SLA</th></tr>
        ${tecnicos.map((t) => `
          <tr>
            <td>${t.nombre}</td><td>${t.especialidad}</td><td>${t.asignados}</td><td>${t.abiertos}</td>
            <td>${luz(colorSla(t.sla))} ${t.sla}%</td>
          </tr>`).join("")}
      </table></div>
      ${referenciaSla}
    </section>`;
}

function marcarMenu(id) {
  document.querySelectorAll(".menu button").forEach((b) => b.classList.remove("activo"));
  document.getElementById(id).classList.add("activo");
}

document.getElementById("nav-resumen").onclick = nivel1;
document.getElementById("nav-tecnicos").onclick = vistaTecnicos;

nivel1();
