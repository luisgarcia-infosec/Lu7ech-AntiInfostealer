# 🛡️ Lu7ech Anti-Infostealer

Script automático para Windows que detecta, aísla y reporta infostealers (RedLine, Lumma, Vidar y variantes similares) sin necesidad de instalar nada ni tener conocimientos técnicos.

## Por qué lo hice

Hoy en día el infostealer es el malware más común que te podés llegar a agarrar: te lo mandan disfrazado de un crack, un cheat, un "activador" de Office, un adjunto de WhatsApp, un instalador trucho de una herramienta... y una vez adentro te roba contraseñas guardadas, cookies de sesión, wallets y datos del navegador sin que te des cuenta, muchas veces sin que ningún antivirus salte.

Lo armé porque me pasó, le pasó a gente cercana, y porque cada vez que alguien me pregunta "che, ¿cómo sé si tengo algo raro en la PC?" quería tener algo para pasarle que no dependa de que la persona sepa leer un log de Defender o ir carpeta por carpeta a mano. La idea es simple: lo corrés, hace todo el laburo de revisión automático, y al final te dice si estás limpio o no — y si hay algo, ya te lo saca de encima.

## Qué hace, paso a paso

El script corre 5 etapas automáticas y te va mostrando todo en pantalla mientras genera un reporte:

**1. Windows Defender**
Actualiza las firmas de virus y dispara un escaneo (elegís rápido o completo). Si Defender ya detectó algo, lo suma directo a la lista de amenazas confirmadas.

**2. Chequeo de persistencia**
Revisa todos los lugares donde un malware se esconde para arrancar solo con Windows: entradas de arranque automático del registro, la carpeta de Inicio, Tareas Programadas, Servicios de Windows y suscripciones WMI. Detecta lo sospechoso por nombre de archivo random (tipo `a8f3kd91.exe`), falta de firma digital, ubicación típica de malware (AppData, Temp, ProgramData) o comandos ofuscados (código codificado en base64, descargas silenciosas, etc.).

**3. Procesos activos**
Busca procesos corriendo en este momento desde carpetas de usuario sin firma digital válida, y si tienen conexiones de red abiertas te muestra a qué IP y puerto están hablando — así ves en vivo si algo te está exfiltrando datos.

**4. Búsqueda de archivos**
Escanea las carpetas más usadas por este tipo de malware (AppData, Temp, Descargas, Escritorio, Documentos) buscando ejecutables o scripts recientes (últimos 90 días) que calcen con los mismos patrones sospechosos.

**5. Cuarentena automática y veredicto**
Todo lo que detecta como malware confirmado lo mata, lo desconecta de donde se esté arrancando solo, y lo manda a una carpeta de cuarentena (`C:\Cuarentena_Lu7ech`) — ahí queda inofensivo, renombrado, pero sin borrarse todavía por si lo querés revisar. Lo dudoso solo lo reporta, no lo toca, para que lo mires vos. Al final te tira un veredicto claro: **Infectado**, **Limpio**, o **Dudoso**, con un reporte .txt completo guardado en el Escritorio, y te pregunta si querés borrar definitivamente lo que quedó en cuarentena.

Para cerrar, te recuerda lo más importante que ningún script puede hacer por vos: desde otro dispositivo limpio, cerrar sesiones activas y cambiar contraseñas con 2FA — porque si te robaron una sesión, borrar el malware no te las devuelve.

## Cómo se corre

1. Descargá el script y guardalo en tu PC.
2. Hacé doble clic — te va a pedir permisos de administrador (es necesario para poder tocar procesos, registro y servicios).
3. Elegís si querés escaneo rápido o completo de Defender.
4. Dejalo correr. Vas a ver en pantalla todo lo que va revisando.
5. Al final te muestra el veredicto y te pregunta si querés eliminar definitivamente lo que puso en cuarentena.
6. El reporte completo queda guardado en tu Escritorio como `Reporte_Infostealer_<fecha>.txt`.

## Cómo está armado

- Un solo archivo `.bat` con PowerShell embebido — sin instalador, sin dependencias externas.
- Autoelevación UAC automática (no hace falta correrlo como admin a mano).
- Motor de reglas basado en: firma digital (Authenticode), rutas típicas de malware, patrones de nombre de archivo, y comandos de ofuscación comunes en loaders.

## Disclaimer

Es una herramienta de uso personal/educativo. Termina procesos, modifica el registro y mueve/borra archivos del sistema — usala bajo tu responsabilidad, revisá siempre el reporte antes de confirmar el borrado definitivo de la cuarentena, y no la tomes como reemplazo de un antivirus o EDR profesional.

---
🔗 Más herramientas: [Lu7ech](https://lgcybersecurity.netlify.app) · [@LuisGarcia-InfoSec](https://github.com/luisgarcia-infosec)
