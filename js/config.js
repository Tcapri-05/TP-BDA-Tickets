// Conexión a Supabase.
// La clave "publishable" es pública: está pensada para usarse en el navegador.
// La seguridad la dan las políticas RLS y la función login() en la base.
const SUPABASE_URL = "https://kqhmetqpmkrkinixfrdf.supabase.co";
const SUPABASE_KEY = "sb_publishable_0_i-FCu--PqD4A8aOw5FDg_2CIMarwm";

const db = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
