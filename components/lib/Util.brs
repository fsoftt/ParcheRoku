' Utilidades generales. Todo es puro (sin red ni registro) para poder probarlo fuera del dispositivo.

' true si v es una cadena (literal o caja).
function IsStr(v as dynamic) as boolean
    t = type(v)
    return t = "roString" or t = "String"
end function

' true si v es un número (entero, flotante, doble).
function IsNum(v as dynamic) as boolean
    t = type(v)
    return t = "roInt" or t = "Integer" or t = "roFloat" or t = "Float" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger"
end function

' Convierte a texto cualquier valor simple; si no se puede, devuelve fallback.
function NzStr(v as dynamic, fallback = "" as string) as string
    if IsStr(v) then return v
    if IsNum(v) then return v.ToStr()
    return fallback
end function

' Convierte a entero (acepta números y cadenas numéricas).
function ToInt(v as dynamic, fallback = 0 as integer) as integer
    if IsNum(v) then return Int(v)
    if IsStr(v) then
        s = v.Trim()
        if s <> "" then return Int(Val(s))
    end if
    return fallback
end function

' Convierte a flotante (acepta números y cadenas numéricas).
function ToFloat(v as dynamic, fallback = 0.0 as float) as float
    if IsNum(v) then return v
    if IsStr(v) then
        s = v.Trim()
        if s <> "" then return Val(s)
    end if
    return fallback
end function

' Une los elementos de un arreglo de cadenas con un separador.
function ArrayJoin(items as object, sep as string) as string
    out = ""
    first = true
    for each it in items
        if first then
            out = NzStr(it)
            first = false
        else
            out = out + sep + NzStr(it)
        end if
    end for
    return out
end function

' true si el arreglo contiene la cadena (sin distinguir mayúsculas).
function ArrayHas(items as object, value as string) as boolean
    for each it in items
        if LCase(NzStr(it)) = LCase(value) then return true
    end for
    return false
end function

' Formatea un número con un decimal ("2.1").
function Fmt1(v as double) as string
    n = Int(v * 10# + 0.5#)
    return (n \ 10).ToStr() + "." + (n mod 10).ToStr()
end function

' Tamaño legible: "2.1 GB", "700 MB". Cadena vacía si no se conoce (bytes <= 0).
function FormatSize(bytes as double) as string
    if bytes <= 0 then return ""
    gb = 1073741824#
    mb = 1048576#
    if bytes >= gb then return Fmt1(bytes / gb) + " GB"
    return Int(bytes / mb + 0.5#).ToStr() + " MB"
end function

' Duración legible a partir de segundos: "1 h 45 min" / "52 min".
function FormatMinutes(minutes as integer) as string
    if minutes <= 0 then return ""
    h = minutes \ 60
    m_ = minutes mod 60
    if h > 0 then return h.ToStr() + " h " + m_.ToStr() + " min"
    return m_.ToStr() + " min"
end function

' Sustituye %1, %2… por los argumentos (como máximo 3).
function FormatArgs(template as string, a1 = invalid as dynamic, a2 = invalid as dynamic, a3 = invalid as dynamic) as string
    out = template
    if a1 <> invalid then out = out.Replace("%1", NzStr(a1))
    if a2 <> invalid then out = out.Replace("%2", NzStr(a2))
    if a3 <> invalid then out = out.Replace("%3", NzStr(a3))
    return out
end function

' Recorta un texto a max caracteres añadiendo "…".
function Ellipsize(s as string, max as integer) as string
    if Len(s) <= max then return s
    return Left(s, max - 1).Trim() + "..."
end function

' Clave estable de un título: id de IMDb si existe; si no, tipo + id de TMDB.
function ItemKey(item as object) as string
    id = NzStr(item.id)
    if Left(id, 2) = "tt" then return id
    return "tmdb:" + NzStr(item.type, "movie") + ":" + NzStr(item.tmdbId, "0")
end function

' Versión compacta de un título para guardar en el registro (que tiene poco espacio).
function CompactItem(item as object) as object
    return {
        id: NzStr(item.id)
        tmdbId: ToInt(item.tmdbId)
        type: NzStr(item.type, "movie")
        title: NzStr(item.title)
        year: ToInt(item.year)
        poster: NzStr(item.poster)
        backdrop: NzStr(item.backdrop)
    }
end function

' Segundos desde 1970 (para ordenar entradas de "Continuar viendo").
function NowSeconds() as integer
    dt = CreateObject("roDateTime")
    return dt.AsSeconds()
end function
