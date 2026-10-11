' Análisis y ranking de fuentes (port de StreamParser.cs y StreamRanker.cs de Parche).
' Todo son funciones puras: reciben JSON ya convertido (ParseJson) y devuelven arreglos/AA.
'
' Un "candidato" es un AA con:
'   addon, name, title, quality ("2160p".."SD"), sizeBytes (doble, 0 = desconocido), provider (origen, puede ser ""),
'   languages (arreglo), url (http/https), fileName, headers (AA), tags (arreglo),
'   priority (entero, mayor = antes; 0 por defecto), availText/availColor (disponibilidad para mostrar, opcional),
'   notice (true = aviso del addon, no es una fuente real). Un plugin puede completar los campos opcionales.

' ---------- constantes ----------

function DefaultLanguages() as object
    return ["es-419", "es", "en"]
end function

function DefaultMaxQuality() as string
    return "1080p"
end function

' ---------- análisis ----------

' Convierte la respuesta de un addon ({ streams: [...] }) en candidatos.
function StreamsParseResponse(json as dynamic, addon as string) as object
    result = []
    if type(json) <> "roAssociativeArray" then return result
    if type(json.streams) <> "roArray" then return result
    for each s in json.streams
        c = StreamParse(s, addon)
        if c <> invalid then result.Push(c)
    end for
    return result
end function

' Convierte un elemento de streams[]; devuelve invalid si no trae un enlace http(s), que es lo único que Roku reproduce.
function StreamParse(s as dynamic, addon as string) as dynamic
    if type(s) <> "roAssociativeArray" then return invalid
    url = NzStr(s.url)
    if LCase(Left(url, 7)) <> "http://" and LCase(Left(url, 8)) <> "https://" then return invalid

    name = NzStr(s.name)
    title = NzStr(s.title)
    if title = "" then title = NzStr(s.description)

    hints = s.behaviorHints
    fileName = ""
    if type(hints) = "roAssociativeArray" then fileName = NzStr(hints.filename)
    if fileName = "" then fileName = StreamFileNameFromTitle(title)

    headers = {}
    if type(hints) = "roAssociativeArray" then
        if type(hints.proxyHeaders) = "roAssociativeArray" then
            if type(hints.proxyHeaders.request) = "roAssociativeArray" then
                for each k in hints.proxyHeaders.request
                    if IsStr(hints.proxyHeaders.request[k]) then headers[k] = hints.proxyHeaders.request[k]
                end for
            end if
        end if
    end if

    text = name + Chr(10) + title
    size = StreamParseSize(title)
    if size <= 0 and type(hints) = "roAssociativeArray" then
        if IsNum(hints.videoSize) then size = hints.videoSize
    end if

    return {
        addon: addon
        name: name
        title: title
        quality: StreamDetectQuality(name + " " + title)
        sizeBytes: size
        provider: ""
        languages: LangDetect(text)
        url: url
        fileName: fileName
        headers: headers
        tags: StreamReleaseTags(text)
        priority: 0
        availText: ""
        availColor: "0x9CA3AFFF"
        notice: false
    }
end function

' Nombre de archivo por defecto: la primera línea no vacía del título.
function StreamFileNameFromTitle(title as string) as string
    for each l in title.Split(Chr(10))
        t = l.Trim()
        if t <> "" then return t
    end for
    return ""
end function

function RxHas(pattern as string, text as string) as boolean
    rx = CreateObject("roRegex", pattern, "i")
    return rx.IsMatch(text)
end function

' "2160p", "1080p", "720p", "480p" o "SD".
function StreamDetectQuality(text as string) as string
    if RxHas("(?<![A-Za-z0-9])(2160p|4k|uhd)(?![A-Za-z0-9])", text) then return "2160p"
    if RxHas("(?<![A-Za-z0-9])1080p?(?![A-Za-z0-9])", text) then return "1080p"
    if RxHas("(?<![A-Za-z0-9])720p?(?![A-Za-z0-9])", text) then return "720p"
    if RxHas("(?<![A-Za-z0-9])(480p|576p|dvdrip)(?![A-Za-z0-9])", text) then return "480p"
    return "SD"
end function

' Orden numérico de una calidad ("2160p" 2160 ... "SD" 360).
function StreamQualityValue(quality as dynamic) as integer
    q = LCase(NzStr(quality))
    if q = "2160p" or q = "4k" then return 2160
    if q = "1440p" then return 1440
    if q = "1080p" then return 1080
    if q = "720p" then return 720
    if q = "480p" then return 480
    return 360
end function

' Tamaño en bytes a partir de un texto como "2.1 GB" (TB, GB o MB); 0 si no aparece.
function StreamParseSize(text as string) as double
    rx = CreateObject("roRegex", "(?<![A-Za-z0-9.,])([0-9]+(?:[.,][0-9]+)?)\s*(TB|GB|MB)(?![A-Za-z])", "i")
    m_ = rx.Match(text)
    if m_.Count() < 3 then return 0#
    n = Val(m_[1].Replace(",", "."))
    unit = UCase(m_[2])
    mult = 1048576#
    if unit = "TB" then
        mult = 1099511627776#
    else if unit = "GB" then
        mult = 1073741824#
    end if
    return n * mult
end function

' Etiquetas del release en orden: origen (remux, bluray, web, tv, dvd, cam), imagen (hdr, 3d) y audio ("7.1", "5.1").
function StreamReleaseTags(text as string) as object
    tags = []
    if RxHas("(?<![A-Za-z0-9])remux(?![A-Za-z0-9])", text) then
        tags.Push("remux")
    else if RxHas("(?<![A-Za-z0-9])(blu-?ray|bdrip|brrip|bd25|bd50)(?![A-Za-z0-9])", text) then
        tags.Push("bluray")
    else if RxHas("(?<![A-Za-z0-9])(web-?dl|web-?rip|web)(?![A-Za-z0-9])", text) then
        tags.Push("web")
    else if RxHas("(?<![A-Za-z0-9])(hdtv|pdtv)(?![A-Za-z0-9])", text) then
        tags.Push("tv")
    else if RxHas("(?<![A-Za-z0-9])(dvd-?rip|dvd|dvd5|dvd9)(?![A-Za-z0-9])", text) then
        tags.Push("dvd")
    else if RxHas("(?<![A-Za-z0-9])(cam|hdcam|camrip|hdts|telesync|telecine)(?![A-Za-z0-9])", text) then
        tags.Push("cam")
    end if
    if RxHas("(?<![A-Za-z0-9])(hdr10\+?|hdr|dolby[ .]?vision|dv)(?![A-Za-z0-9])", text) then tags.Push("hdr")
    if RxHas("(?<![A-Za-z0-9])(3d|h-?sbs|sbs)(?![A-Za-z0-9])", text) then tags.Push("3d")
    rx = CreateObject("roRegex", "(?<![0-9])([57]\.1)(?![0-9])", "")
    a = rx.Match(text)
    if a.Count() > 1 then tags.Push(a[1])
    return tags
end function

' Formato de reproducción de Roku según la extensión de la URL ("" si no se reconoce y Roku debe detectarlo).
function GuessStreamFormat(url as string) as string
    path = LCase(url.Split("?")[0].Split("#")[0])
    if Right(path, 5) = ".m3u8" then return "hls"
    if Right(path, 4) = ".mpd" then return "dash"
    if Right(path, 4) = ".mkv" then return "mkv"
    if Right(path, 4) = ".mp4" or Right(path, 4) = ".m4v" or Right(path, 4) = ".mov" then return "mp4"
    if Right(path, 3) = ".ts" then return "ts"
    return ""
end function

' ---------- filtrado y ranking ----------

' Solo las fuentes que Roku puede reproducir: tienen un enlace HTTP(S) directo y no son avisos del addon.
function StreamsPlayableOnly(candidates as object) as object
    result = []
    for each c in candidates
        url = LCase(NzStr(c.url))
        isHttp = Left(url, 7) = "http://" or Left(url, 8) = "https://"
        if isHttp and c.notice <> true then result.Push(c)
    end for
    return result
end function

' Quita duplicados por URL conservando el primero.
function StreamsDedupe(candidates as object) as object
    seen = {}
    result = []
    for each c in candidates
        key = c.url
        if not seen.DoesExist(key) then
            seen[key] = true
            result.Push(c)
        end if
    end for
    return result
end function

' Texto del que se lee el año de una fuente: el nombre del archivo o, si no hay, el título.
function StreamYearText(c as object) as string
    text = NzStr(c.fileName)
    if text = "" then text = NzStr(c.title)
    return text
end function

' Año de publicación según el nombre del release (primera línea). Busca números 19xx/20xx sueltos: no van
' pegados a otro dígito ni a x/X delante, ni seguidos de dígito, x/X o p/P ("1920x1080", "2160p" no son años).
' Si hay varios, devuelve el último ("Blade.Runner.2049.2017" -> 2017). Sin año, invalid.
function StreamParseYear(text as string) as dynamic
    line = text.Split(Chr(10))[0]
    n = Len(line)
    year = invalid
    i = 1
    while i <= n
        if StreamIsDigit(Mid(line, i, 1)) then
            j = i
            while j < n and StreamIsDigit(Mid(line, j + 1, 1))
                j = j + 1
            end while
            digits = Mid(line, i, j - i + 1)
            if Len(digits) = 4 and (Left(digits, 2) = "19" or Left(digits, 2) = "20") then
                before = ""
                if i > 1 then before = Mid(line, i - 1, 1)
                after = ""
                if j < n then after = Mid(line, j + 1, 1)
                ok = true
                if before <> "" and Instr(1, "xX", before) > 0 then ok = false
                if after <> "" and Instr(1, "xXpP", after) > 0 then ok = false
                if ok then year = Int(Val(digits))
            end if
            i = j + 1
        else
            i = i + 1
        end if
    end while
    return year
end function

function StreamIsDigit(ch as string) as boolean
    return ch <> "" and Instr(1, "0123456789", ch) > 0
end function

' Quita las fuentes cuyo año en el nombre difiere del de la película (tolerancia ±1). Sin año leído se conservan.
' Algunos addons mezclan remakes bajo el mismo id de IMDb ("Night.of.the.Living.Dead.2026" para la de 1968).
function StreamsDropOtherYears(candidates as object, year as integer) as object
    result = []
    for each c in candidates
        y = StreamParseYear(StreamYearText(c))
        if y = invalid then
            result.Push(c)
        else if Abs(y - year) <= 1 then
            result.Push(c)
        end if
    end for
    return result
end function

' Posición de la mejor preferencia que cumple (0 = la primera). "multi" cuenta tras todas las preferidas;
' sin coincidencia = Count + 1.
function StreamLanguageRank(c as object, preferred as object) as integer
    for i = 0 to preferred.Count() - 1
        for each l in c.languages
            if LangMatches(preferred[i], l) then return i
        end for
    end for
    if ArrayHas(c.languages, LangMulti()) then return preferred.Count()
    return preferred.Count() + 1
end function

' Calidades dentro del tope puntúan por su valor (mayor mejor); las que lo exceden quedan después, de menor a mayor.
function StreamQualityScore(c as object, maxQuality as integer) as integer
    q = StreamQualityValue(c.quality)
    if q <= maxQuality then return 10000 + q
    return 10000 - q
end function

' true si a debe ir antes que b (priority, langRank, qualityScore, size ya precalculados en r*).
function StreamRankBefore(a as object, b as object) as boolean
    if a.rPriority <> b.rPriority then return a.rPriority > b.rPriority
    if a.rLang <> b.rLang then return a.rLang < b.rLang
    if a.rQuality <> b.rQuality then return a.rQuality > b.rQuality
    return a.sizeBytes > b.sizeBytes
end function

' Ordena sin descartar nada: prioridad (la fija un plugin; 0 por defecto), idioma preferido, calidad
' (con tope preferido) y tamaño. Los idiomas solo desempatan: ocultar las fuentes de otro idioma deja solo opciones lentas. maxQuality "" = sin tope. La ordenación es estable.
function StreamsRank(candidates as object, preferredLanguages = invalid as dynamic, maxQuality = "1080p" as dynamic) as object
    langs = DefaultLanguages()
    if type(preferredLanguages) = "roArray" then
        if preferredLanguages.Count() > 0 then langs = preferredLanguages
    end if
    maxQ = 2147483647
    if IsStr(maxQuality) then
        if maxQuality.Trim() <> "" then maxQ = StreamQualityValue(maxQuality)
    end if

    items = []
    for each c in candidates
        c.rPriority = ToInt(c.priority)
        c.rLang = StreamLanguageRank(c, langs)
        c.rQuality = StreamQualityScore(c, maxQ)
        items.Push(c)
    end for

    ' Ordenación por inserción (estable); las listas son pequeñas (< 300).
    n = items.Count()
    for i = 1 to n - 1
        cur = items[i]
        j = i - 1
        while j >= 0
            if StreamRankBefore(cur, items[j]) then
                items[j + 1] = items[j]
                j = j - 1
            else
                exit while
            end if
        end while
        items[j + 1] = cur
    end for
    return items
end function

' Filtra, conservando el orden, las fuentes que declaran EXPLÍCITAMENTE el idioma code ("es", "es-419", "en").
' Las marcadas solo como "multi" (DUAL/MULTI sin detalle) no cuentan: aparecen solo con code vacío (Todos).
function StreamsFilterByLanguage(candidates as object, code as dynamic) as object
    c_ = LCase(NzStr(code))
    if c_ = "" then return candidates
    result = []
    for each c in candidates
        if ArrayHas(c.languages, c_) then result.Push(c)
    end for
    return result
end function

' ---------- descripción en lenguaje llano ----------

' Nombre legible de una etiqueta de release ("remux" -> "Blu-ray original").
function StreamTagLabel(tag as string) as string
    if tag = "remux" then return Tx("tag_remux")
    if tag = "bluray" then return Tx("tag_bluray")
    if tag = "web" then return Tx("tag_web")
    if tag = "tv" then return Tx("tag_tv")
    if tag = "dvd" then return Tx("tag_dvd")
    if tag = "cam" then return Tx("tag_cam")
    if tag = "hdr" then return "HDR"
    if tag = "3d" then return "3D"
    return Tx("tag_audio", tag)
end function

' Orden de presentación de idiomas: Latino antes que Castellano; el resto conserva su orden.
function StreamLangsForDisplay(langs as object) as object
    out = []
    for each code in ["es-419", "es"]
        if ArrayHas(langs, code) then out.Push(code)
    end for
    for each l in langs
        if not ArrayHas(out, l) then out.Push(l)
    end for
    return out
end function

' Describe una fuente en lenguaje llano.
' Devuelve { line1, line2, avail, availColor }.
'   line1: "1080p · Blu-ray original · 2.1 GB"
'   line2: "Origen: YTS · Latino, Castellano"
'   avail: disponibilidad, si el plugin la informa ("" si no)
function StreamDescribe(c as object) as object
    bullet = " " + Chr(183) + " "
    parts = [c.quality]
    for each t in c.tags
        parts.Push(StreamTagLabel(t))
    end for
    size = FormatSize(c.sizeBytes)
    if size <> "" then parts.Push(size)

    parts2 = []
    if c.provider <> "" then parts2.Push(Tx("src_origin", c.provider))
    langNames = []
    for each l in StreamLangsForDisplay(c.languages)
        langNames.Push(LangLabel(l))
    end for
    parts2.Push(ArrayJoin(langNames, ", "))

    avail = NzStr(c.availText)
    color = NzStr(c.availColor, "0x9CA3AFFF")

    return {
        line1: ArrayJoin(parts, bullet)
        line2: ArrayJoin(parts2, bullet)
        avail: avail
        availColor: color
    }
end function
