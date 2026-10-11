' Puntos de extensión (plugins). Esta es la versión pública: un cliente neutro de addons, sin extras.
' Al empaquetar, si existe un plugin (ver scripts/plugins.js), su components/lib/Plugins.brs REEMPLAZA a este archivo.
' Un plugin debe definir TODAS estas funciones, con estas firmas. Aquí devuelven valores neutros.
'
'   PluginSettingsNormalize(raw, s)      completa/valida los ajustes propios del plugin dentro de s (ya normalizado).
'                                        raw es el JSON guardado; los campos desconocidos ya vienen copiados a s.
'   PluginStreamAddons(s)                URLs base extra de addons de fuentes (arreglo de cadenas, sin "/stream/...").
'   PluginStreamEnrich(c, raw, s)        recibe un candidato ya analizado (ver Streams.brs) y el JSON original del
'                                        stream; devuelve el candidato con campos extra: priority (entero, mayor =
'                                        antes), availText/availColor, provider, fileName, notice (true = aviso del
'                                        addon, no es una fuente real).
'   PluginSettingsItems(s)               filas extra de Ajustes: [{ id, title, desc, value }] (se muestran tras la
'                                        clave de TMDB).
'   PluginSettingsWarning(s)             texto de advertencia para Ajustes, o invalid.
'   PluginHandleSetting(s, id)           el usuario pulsó OK en una fila del plugin. Devuelve
'                                        { settings: s, ask: invalid | { title, message, text } }; si ask no es
'                                        invalid se abre un teclado y luego se llama a PluginApplyKeyboard.
'   PluginApplyKeyboard(s, id, text)     aplica el texto escrito; devuelve los ajustes.
'   PluginSourcesNotice(s)               texto para el selector de fuentes cuando no hay ningún addon efectivo, o
'                                        invalid para el aviso estándar ("agrega un addon").
'   PluginStrings()                      traducciones extra o que reemplazan a las de Strings.brs:
'                                        { clave: [español, inglés, portugués] }.

' bs:disable-next-line
function PluginSettingsNormalize(raw as object, s as object) as object
    return s
end function

' bs:disable-next-line
function PluginStreamAddons(s as object) as object
    return []
end function

' bs:disable-next-line
function PluginStreamEnrich(c as object, raw as object, s as object) as object
    return c
end function

' bs:disable-next-line
function PluginSettingsItems(s as object) as object
    return []
end function

' bs:disable-next-line
function PluginSettingsWarning(s as object) as dynamic
    return invalid
end function

' bs:disable-next-line
function PluginHandleSetting(s as object, id as string) as object
    return { settings: s, ask: invalid }
end function

' bs:disable-next-line
function PluginApplyKeyboard(s as object, id as string, text as string) as object
    return s
end function

' bs:disable-next-line
function PluginSourcesNotice(s as object) as dynamic
    return invalid
end function

' bs:disable-next-line
function PluginStrings() as object
    return {}
end function
