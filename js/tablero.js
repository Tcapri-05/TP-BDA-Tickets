// =====================================================================
// TABLERO (2ª entrega)
// Todos los datos salen de la base: cada pantalla llama a una función
// SQL de sql/04_consultas.sql con db.rpc().
// =====================================================================

const usuario = exigirSesion();
document.getElementById("nombre-usuario").textContent = usuario ? usuario.nombre : "";

// ---------- Consultas a la base ----------
async function consultar(funcion, parametros = {}) {
  const { data, error } = await db.rpc(funcion, parametros);
  if (error) throw error;
  return data;
}

// ---------- Semáforo ----------
// Porcentaje de tickets resueltos dentro del SLA:
//   verde >= 90%  |  amarillo 75% a 89%  |  rojo < 75%
function colorSla(porcentaje) {
  if (porcentaje === null) return "sin-dato";
  if (porcentaje >= 90) return "verde";
  if (porcentaje >= 75) return "amarillo";
  return "rojo";
}

// Para un ticket: tiempo usado respecto del SLA de su prioridad.
//   verde: usó menos del 75%  |  amarillo: entre 75% y 100%  |  rojo: venció
function colorTicket(t) {
  const uso = t.horas / t.sla_horas;
  if (uso > 1) return "rojo";
  if (uso >= 0.75) return "amarillo";
  return "verde";
}

const luz = (color) => `<span class="luz ${color}"></span>`;

// ---------- Formatos ----------
const porcentaje = (p) => (p === null ? "—" : `${p}%`);
const horas = (h) => (h === null ? "—" : `${Number(h).toLocaleString("es-AR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })} h`);

// Los textos que vienen de la base se escapan antes de ponerlos en el HTML.
function texto(valor) {
  const div = document.createElement("div");
  div.textContent = valor ?? "";
  return div.innerHTML;
}

const referenciaSla = `
  <div class="referencia">
    <span>${luz("verde")} Verde: 90% o más de tickets dentro del SLA</span>
    <span>${luz("amarillo")} Amarillo: entre 75% y 89%</span>
    <span>${luz("rojo")} Rojo: menos de 75% (situación crítica)</span>
  </div>`;

function barras(filas, campo) {
  const max = Math.max(1, ...filas.map((f) => f[campo]));
  return `<div class="barras">${filas.map((f) => `
    <div class="barra">
      <span>${texto(f.nombre)}</span>
      <div class="pista"><div class="relleno" style="width:${(f[campo] / max) * 100}%"></div></div>
      <strong>${f[campo]}</strong>
    </div>`).join("")}</div>`;
}

// ---------- Navegación (Drill Down / Drill Up) ----------
const vista = document.getElementById("vista");
let departamentos = [];
let deptoActual = null;
let categoriaActual = null;
let pedido = 0; // descarta respuestas viejas si el usuario hace clic rápido

function migas() {
  let html = `<a onclick="nivel1()">Todos los departamentos</a>`;
  if (deptoActual) html += ` › <a onclick="nivel2(${deptoActual.id})">${texto(deptoActual.nombre)}</a>`;
  if (categoriaActual) html += ` › ${texto(categoriaActual.nombre)}`;
  return `<div class="migas">${html}</div>`;
}

// Muestra "Cargando...", ejecuta la consulta y dibuja la pantalla.
// Si la base no responde, muestra un mensaje en vez de dejar la pantalla vacía.
async function mostrar(cargar) {
  const numero = ++pedido;
  vista.innerHTML = `<p class="cargando">Cargando datos…</p>`;
  try {
    const html = await cargar();
    if (numero === pedido) vista.innerHTML = html;
  } catch (error) {
    console.error(error);
    if (numero === pedido) {
      vista.innerHTML = `<p class="mensaje-error">No se pudieron cargar los datos de la base. Revisá la conexión y volvé a intentar.</p>`;
    }
  }
}

// NIVEL 1: resumen general por departamento
function nivel1() {
  deptoActual = null;
  categoriaActual = null;
  marcarMenu("nav-resumen");

  mostrar(async () => {
    const [[general], deptos, sinTecnico] = await Promise.all([
      consultar("resumen_general"),
      consultar("resumen_departamentos"),
      consultar("tickets_sin_tecnico"),
    ]);
    departamentos = deptos;

    return `
      <div class="encabezado"><h2>Resumen general</h2></div>
      ${migas()}
      <div class="kpis">
        <div class="kpi"><div class="titulo">Tickets (últimos 90 días)</div><div class="valor">${general.tickets}</div></div>
        <div class="kpi"><div class="titulo">Abiertos / en progreso</div><div class="valor">${general.pendientes}</div></div>
        <div class="kpi"><div class="titulo">Resueltos dentro del SLA</div><div class="valor">${luz(colorSla(general.pct_sla))} ${porcentaje(general.pct_sla)}</div></div>
        <div class="kpi"><div class="titulo">Tiempo promedio de resolución</div><div class="valor">${horas(general.horas_promedio)}</div></div>
      </div>
      <div class="grilla">
        <section class="panel">
          <h3>Tickets por departamento</h3>
          ${barras(deptos, "tickets")}
        </section>
        <section class="panel">
          <h3>Cumplimiento de SLA por departamento</h3>
          <div class="tabla-scroll"><table>
            <tr><th>Departamento</th><th>Tickets</th><th>Abiertos</th><th>SLA</th></tr>
            ${deptos.map((d) => `
              <tr class="clic" onclick="nivel2(${d.id})">
                <td>${texto(d.nombre)}</td><td>${d.tickets}</td><td>${d.pendientes}</td>
                <td>${luz(colorSla(d.pct_sla))} ${porcentaje(d.pct_sla)}</td>
              </tr>`).join("")}
          </table></div>
          <p class="ayuda">Hacé clic en un departamento para ver sus categorías.</p>
        </section>
      </div>
      ${referenciaSla}
      <section class="panel alerta">
        <h3>Tickets pendientes sin técnico asignado (${sinTecnico.length})</h3>
        ${sinTecnico.length === 0 ? `<p class="ayuda">No hay tickets pendientes sin asignar.</p>` : `
        <div class="tabla-scroll"><table>
          <tr><th>#</th><th>Título</th><th>Departamento</th><th>Prioridad</th><th>Horas / SLA</th><th></th></tr>
          ${sinTecnico.map((t) => `
            <tr>
              <td>${t.id}</td><td>${texto(t.titulo)}</td><td>${texto(t.departamento)}</td><td>${texto(t.prioridad)}</td>
              <td>${horas(t.horas)} / ${t.sla_horas} h</td>
              <td>${luz(colorTicket(t))}</td>
            </tr>`).join("")}
        </table></div>`}
      </section>`;
  });
}

// NIVEL 2: categorías de problemas dentro de un departamento
function nivel2(idDepto) {
  categoriaActual = null;

  mostrar(async () => {
    if (departamentos.length === 0) departamentos = await consultar("resumen_departamentos");
    deptoActual = departamentos.find((d) => d.id === idDepto);
    const categorias = await consultar("resumen_categorias", { p_departamento: idDepto });
    window.categoriasActuales = categorias;

    return `
      <div class="encabezado">
        <h2>${texto(deptoActual.nombre)}</h2>
        <button class="btn-volver" onclick="nivel1()">← Volver</button>
      </div>
      ${migas()}
      <div class="kpis">
        <div class="kpi"><div class="titulo">Tickets del departamento</div><div class="valor">${deptoActual.tickets}</div></div>
        <div class="kpi"><div class="titulo">Abiertos</div><div class="valor">${deptoActual.pendientes}</div></div>
        <div class="kpi"><div class="titulo">Dentro del SLA</div><div class="valor">${luz(colorSla(deptoActual.pct_sla))} ${porcentaje(deptoActual.pct_sla)}</div></div>
        <div class="kpi"><div class="titulo">Tiempo promedio de resolución</div><div class="valor">${horas(deptoActual.horas_promedio)}</div></div>
      </div>
      <div class="grilla">
        <section class="panel">
          <h3>Tickets por categoría</h3>
          ${barras(categorias, "tickets")}
        </section>
        <section class="panel">
          <h3>Detalle por categoría</h3>
          <div class="tabla-scroll"><table>
            <tr><th>Categoría</th><th>Tickets</th><th>Prom. resolución</th><th>SLA</th></tr>
            ${categorias.map((c) => `
              <tr class="clic" onclick="nivel3(${c.id})">
                <td>${texto(c.nombre)}</td><td>${c.tickets}</td><td>${horas(c.horas_promedio)}</td>
                <td>${luz(colorSla(c.pct_sla))} ${porcentaje(c.pct_sla)}</td>
              </tr>`).join("")}
          </table></div>
          <p class="ayuda">Hacé clic en una categoría para ver los tickets.</p>
        </section>
      </div>
      ${referenciaSla}`;
  });
}

// NIVEL 3: listado de tickets de una categoría en un departamento
function nivel3(idCategoria) {
  categoriaActual = window.categoriasActuales.find((c) => c.id === idCategoria);

  mostrar(async () => {
    const tickets = await consultar("detalle_tickets", {
      p_departamento: deptoActual.id,
      p_categoria: idCategoria,
    });

    return `
      <div class="encabezado">
        <h2>${texto(categoriaActual.nombre)} · ${texto(deptoActual.nombre)}</h2>
        <button class="btn-volver" onclick="nivel2(${deptoActual.id})">← Volver</button>
      </div>
      ${migas()}
      <section class="panel">
        <h3>Tickets (${tickets.length})</h3>
        ${tickets.length === 0 ? `<p class="ayuda">Este departamento no tiene tickets de esta categoría.</p>` : `
        <div class="tabla-scroll"><table>
          <tr><th>#</th><th>Título</th><th>Solicitante</th><th>Prioridad</th><th>Técnico</th><th>Estado</th><th>Horas / SLA</th><th></th></tr>
          ${tickets.map((t) => `
            <tr>
              <td>${t.id}</td><td>${texto(t.titulo)}</td><td>${texto(t.solicitante)}</td><td>${texto(t.prioridad)}</td>
              <td>${t.tecnico ? texto(t.tecnico) : "Sin asignar"}</td>
              <td><span class="etiqueta">${texto(t.estado)}</span></td>
              <td>${horas(t.horas)} / ${t.sla_horas} h</td>
              <td>${luz(colorTicket(t))}</td>
            </tr>`).join("")}
        </table></div>`}
        <div class="referencia">
          <span>${luz("verde")} Usó menos del 75% del plazo</span>
          <span>${luz("amarillo")} Usó 75% o más del plazo</span>
          <span>${luz("rojo")} Plazo (SLA) vencido</span>
        </div>
        <p class="ayuda">En los tickets pendientes, las horas son el tiempo que llevan abiertos; en los resueltos, lo que tardó la resolución.</p>
      </section>`;
  });
}

// Vista de técnicos (carga de trabajo)
function vistaTecnicos() {
  deptoActual = null;
  categoriaActual = null;
  marcarMenu("nav-tecnicos");

  mostrar(async () => {
    const tecnicos = await consultar("resumen_tecnicos");

    return `
      <div class="encabezado"><h2>Técnicos</h2></div>
      <p class="migas">Carga de trabajo y cumplimiento de cada técnico</p>
      <div class="grilla">
        <section class="panel">
          <h3>Tickets asignados por técnico</h3>
          ${barras(tecnicos, "asignados")}
        </section>
        <section class="panel">
          <h3>Cumplimiento de SLA por técnico</h3>
          <div class="tabla-scroll"><table>
            <tr><th>Técnico</th><th>Especialidad</th><th>Asignados</th><th>Abiertos</th><th>Prom. resolución</th><th>SLA</th></tr>
            ${tecnicos.map((t) => `
              <tr>
                <td>${texto(t.nombre)}</td><td>${texto(t.especialidad)}</td><td>${t.asignados}</td><td>${t.pendientes}</td>
                <td>${horas(t.horas_promedio)}</td>
                <td>${luz(colorSla(t.pct_sla))} ${porcentaje(t.pct_sla)}</td>
              </tr>`).join("")}
          </table></div>
        </section>
      </div>
      ${referenciaSla}`;
  });
}

function marcarMenu(id) {
  document.querySelectorAll(".menu button").forEach((b) => b.classList.remove("activo"));
  document.getElementById(id).classList.add("activo");
}

document.getElementById("nav-resumen").onclick = nivel1;
document.getElementById("nav-tecnicos").onclick = vistaTecnicos;

if (usuario) nivel1();
