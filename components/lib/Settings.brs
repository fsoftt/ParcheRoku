' Ajustes de la app, lista de addons y lógica de "Continuar viendo" / "Mi lista".
' Las funciones de este archivo son puras salvo las que empiezan por Store* (registro de Roku).

' ---------- ajustes ----------

' Presets de idiomas preferidos (en orden de preferencia).
function LanguagePresets() as object
    return [
        ["es-419", "es", "en"]
        ["es", "es-419", "en"]
        ["en", "es", "es-419"]
        ["pt", "es", "en"]
    ]
end function

' Presets de idiomas de subtítulos (ISO 639-2). El vacío significa "sin subtítulos".
function SubtitlePresets() as object
    return [
        ["spa", "eng"]
        ["eng", "spa"]
        ["por", "spa"]
        []
    ]
end function

function QualityOptions() as object
    return ["2160p", "1080p", "720p", "480p", ""]
end function

function SettingsDefaults() as object
    return {
        uiLang: "es"
        catalog: "auto"
        tmdbKey: ""
        streamAddons: []
        subAddons: [SubtitleAddonDefault()]
        prefLangs: DefaultLanguages()
        maxQuality: DefaultMaxQuality()
        subLangs: ["spa", "eng"]
    }
end function

' Completa con valores por defecto lo que falte o sea inválido (JSON viejo o editado a mano).
function SettingsNormalize(raw as dynamic) as object
    s = SettingsDefaults()
    if type(raw) <> "roAssociativeArray" then return PluginSettingsNormalize({}, s)
    ' Los campos que esta versión no conoce (p. ej. los de un plugin o de una versión anterior) se conservan.
    for each k in raw
        if not s.DoesExist(k) then s[k] = raw[k]
    end for
    if IsStr(raw.uiLang) then
        if raw.uiLang = "en" or raw.uiLang = "es" then s.uiLang = raw.uiLang
    end if
    if IsStr(raw.catalog) then
        if raw.catalog = "tmdb" or raw.catalog = "cinemeta" or raw.catalog = "auto" then s.catalog = raw.catalog
    end if
    if IsStr(raw.tmdbKey) then s.tmdbKey = raw.tmdbKey.Trim()
    if type(raw.streamAddons) = "roArray" then s.streamAddons = AddonListClean(raw.streamAddons)
    ' Sin lista guardada (ajustes de una versión anterior) se queda el addon de subtítulos por defecto.
    if type(raw.subAddons) = "roArray" then s.subAddons = AddonListClean(raw.subAddons)
    if type(raw.prefLangs) = "roArray" then
        if raw.prefLangs.Count() > 0 then s.prefLangs = raw.prefLangs
    end if
    if IsStr(raw.maxQuality) then s.maxQuality = raw.maxQuality
    if type(raw.subLangs) = "roArray" then s.subLangs = raw.subLangs
    return PluginSettingsNormalize(raw, s)
end function

function StripSpaces(v as string) as string
    return v.Replace(" ", "").Replace(Chr(10), "").Replace(Chr(13), "").Replace(Chr(9), "")
end function

' Proveedor de catálogo efectivo: "tmdb" si se pidió TMDB (o auto) y hay clave; si no "cinemeta".
function SettingsCatalogProvider(s as object) as string
    hasKey = s.tmdbKey <> ""
    if s.catalog = "tmdb" and hasKey then return "tmdb"
    if s.catalog = "auto" and hasKey then return "tmdb"
    return "cinemeta"
end function

' ---------- addons ----------

function SubtitleAddonDefault() as string
    return "https://opensubtitles-v3.strem.io"
end function

' URL base de un addon a partir de lo que escribió o pegó el usuario: acepta la URL del manifest
' ("https://host/ruta/manifest.json") o "stremio://host/ruta". Devuelve "" si no es una URL http(s) válida.
function AddonNormalizeUrl(text as string) as string
    t = StripSpaces(text)
    if LCase(Left(t, 10)) = "stremio://" then t = "https://" + Mid(t, 11)
    lower = LCase(t)
    rest = ""
    if Left(lower, 8) = "https://" then
        rest = Mid(t, 9)
    else if Left(lower, 7) = "http://" then
        rest = Mid(t, 8)
    else
        return ""
    end if
    if LCase(Right(t, 14)) = "/manifest.json" then t = Left(t, Len(t) - 14)
    while Right(t, 1) = "/"
        t = Left(t, Len(t) - 1)
    end while
    if rest = "" or Right(t, 3) = "://" then return ""
    return t
end function

' Normaliza cada elemento y quita vacíos y repetidos (conserva el orden).
function AddonListClean(list as object) as object
    out = []
    for each u in list
        if IsStr(u) then
            n = AddonNormalizeUrl(u)
            if n <> "" and not ArrayHas(out, n) then out.Push(n)
        end if
    end for
    return out
end function

' Agrega una URL a la lista (normalizada y sin repetir). Devuelve la lista nueva.
function AddonListAdd(list as object, url as string) as object
    n = AddonNormalizeUrl(url)
    out = []
    for each u in list
        out.Push(u)
    end for
    if n <> "" and not ArrayHas(out, n) then out.Push(n)
    return out
end function

' Quita el elemento en la posición index. Devuelve la lista nueva.
function AddonListRemove(list as object, index as integer) as object
    out = []
    for i = 0 to list.Count() - 1
        if i <> index then out.Push(list[i])
    end for
    return out
end function

' Addons de fuentes efectivos: los del usuario más los del plugin, sin repetir.
function AddonsEffective(s as object) as object
    out = []
    for each u in s.streamAddons
        if not ArrayHas(out, u) then out.Push(u)
    end for
    for each u in PluginStreamAddons(s)
        if not ArrayHas(out, u) then out.Push(u)
    end for
    return out
end function

' Nombre corto para mostrar un addon sin revelar rutas ni claves incrustadas: solo el dominio.
function AddonLabel(url as string) as string
    rest = url
    p = Instr(1, rest, "://")
    if p > 0 then rest = Mid(rest, p + 3)
    return rest.Split("/")[0]
end function

' URL de streams: {base}/stream/{movie|series}/{id}.json. id = "tt123" o "tt123:1:2".
' Roku (curl) rechaza "|" sin codificar en la URL, por eso se codifica como %7C.
function AddonStreamUrl(base as string, mediaType as string, id as string) as string
    return base.Replace("|", "%7C") + "/stream/" + mediaType + "/" + id + ".json"
end function

' URL de subtítulos: {base}/subtitles/{movie|series}/{id}.json.
function AddonSubtitlesUrl(base as string, mediaType as string, id as string) as string
    return base.Replace("|", "%7C") + "/subtitles/" + mediaType + "/" + id + ".json"
end function

' ---------- Continuar viendo (puro) ----------
' Una entrada: { item (compacto), season, episode (enteros, -1 en películas), episodeTitle, positionMs, durationMs,
'                updated (segundos), source ({url, name, quality, headers}) o invalid }

function CwMinPositionMs() as integer
    return 60000
end function

function CwMaxEntries() as integer
    return 15
end function

' Una entrada es de un título "identificable" si tiene id de IMDb o de TMDB.
function CwIdentifiable(item as object) as boolean
    if Left(NzStr(item.id), 2) = "tt" then return true
    return ToInt(item.tmdbId) > 0
end function

' ¿Mismo título? Igual id de IMDb, o mismo tipo e id de TMDB.
function CwSameTitle(a as object, b as object) as boolean
    ia = NzStr(a.id)
    ib = NzStr(b.id)
    if Left(ia, 2) = "tt" and Left(ib, 2) = "tt" and ia = ib then return true
    ta = ToInt(a.tmdbId)
    tb = ToInt(b.tmdbId)
    if ta > 0 and ta = tb and NzStr(a.type) = NzStr(b.type) then return true
    return false
end function

' Fracción vista (0..1).
function CwFraction(entry as object) as float
    if ToInt(entry.durationMs) <= 0 then return 0.0
    f = entry.positionMs / entry.durationMs
    if f < 0 then return 0.0
    if f > 1 then return 1.0
    return f
end function

' Registra el avance y devuelve la lista nueva (más reciente primero). Ignora lo visto menos de un minuto y quita lo
' terminado (>= 92 %). No modifica la lista original.
function CwReport(entries as object, entry as object) as object
    result = []
    for i = 0 to entries.Count() - 1
        ' Se descarta la entrada anterior del mismo título; la nueva se inserta al principio más abajo.
        if not CwSameTitle(entries[i].item, entry.item) then result.Push(entries[i])
    end for
    if not CwIdentifiable(entry.item) then return entries

    dur = ToInt(entry.durationMs)
    position = ToInt(entry.positionMs)
    if dur > 0 and position >= dur * 0.92 then return result ' terminada: se quita
    if position < CwMinPositionMs() then return entries ' muy poco visto: la lista queda como estaba

    out = [entry]
    for each e in result
        if out.Count() < CwMaxEntries() then out.Push(e)
    end for
    return out
end function

' Entrada guardada para ese título y episodio (season/episode -1 en películas), o invalid.
function CwFind(entries as object, item as object, season as integer, episode as integer) as dynamic
    for each e in entries
        if CwSameTitle(e.item, item) and ToInt(e.season, -1) = season and ToInt(e.episode, -1) = episode then return e
    end for
    return invalid
end function

' Entrada más reciente del título (cualquier episodio), o invalid.
function CwFindTitle(entries as object, item as object) as dynamic
    for each e in entries
        if CwSameTitle(e.item, item) then return e
    end for
    return invalid
end function

' ---------- Mi lista (puro) ----------

function MlMaxEntries() as integer
    return 50
end function

function MlContains(list as object, item as object) as boolean
    for each it in list
        if CwSameTitle(it, item) then return true
    end for
    return false
end function

' Añade o quita el título; devuelve la lista nueva (lo último añadido primero).
function MlToggle(list as object, item as object) as object
    result = []
    removed = false
    for each it in list
        if CwSameTitle(it, item) then
            removed = true
        else
            result.Push(it)
        end if
    end for
    if removed then return result
    out = [CompactItem(item)]
    for each it in result
        if out.Count() < MlMaxEntries() then out.Push(it)
    end for
    return out
end function

' ---------- registro de Roku ----------

function StoreSectionName() as string
    return "Parche"
end function

function StoreRead(key as string) as dynamic
    sec = CreateObject("roRegistrySection", StoreSectionName())
    if sec.Exists(key) then return ParseJson(sec.Read(key))
    return invalid
end function

function StoreWrite(key as string, value as object) as boolean
    sec = CreateObject("roRegistrySection", StoreSectionName())
    ok = sec.Write(key, FormatJson(value))
    sec.Flush()
    return ok
end function

function SettingsLoad() as object
    return SettingsNormalize(StoreRead("settings"))
end function

sub SettingsSave(s as object)
    StoreWrite("settings", s)
end sub

function WatchLoad() as object
    v = StoreRead("watch")
    if type(v) = "roArray" then return v
    return []
end function

' Guarda el avance de reproducción (ver CwReport).
sub WatchReport(entry as object)
    StoreWrite("watch", CwReport(WatchLoad(), entry))
end sub

sub WatchClear()
    StoreWrite("watch", [])
end sub

function MyListLoad() as object
    v = StoreRead("mylist")
    if type(v) = "roArray" then return v
    return []
end function

' Añade o quita de Mi lista; devuelve true si ahora está en la lista.
function MyListToggle(item as object) as boolean
    list = MlToggle(MyListLoad(), item)
    StoreWrite("mylist", list)
    return MlContains(list, item)
end function

function MyListHas(item as object) as boolean
    return MlContains(MyListLoad(), item)
end function
