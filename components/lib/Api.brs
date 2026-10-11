' Acceso a red (roUrlTransfer) y operaciones de alto nivel. Se ejecuta SIEMPRE dentro de un Task (ApiTask),
' nunca en el hilo de render.

' Crea la petición GET (con certificados y cabeceras) asociada al puerto.
function HttpNewGet(url as string, headers as dynamic, port as object) as object
    req = CreateObject("roUrlTransfer")
    req.SetMessagePort(port)
    req.SetUrl(url)
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.EnableEncodings(true)
    req.RetainBodyOnError(true)
    req.AddHeader("Accept", "application/json")
    if type(headers) = "roAssociativeArray" then
        for each k in headers
            req.AddHeader(k, headers[k])
        end for
    end if
    return req
end function

' GET con tiempo límite y un reintento. Devuelve { ok, code, body, json }.
function HttpGet(url as string, headers = invalid as dynamic, timeoutMs = 20000 as integer, attempts = 2 as integer) as object
    return HttpGetMany([url], headers, timeoutMs, attempts)[0]
end function

' GET de varias URL a la vez (cada una con tiempo límite timeoutMs y hasta attempts intentos; los 4xx no se
' reintentan). Devuelve un arreglo de { ok, code, body, json } en el mismo orden que urls.
function HttpGetMany(urls as object, headers = invalid as dynamic, timeoutMs = 20000 as integer, attempts = 2 as integer) as object
    results = []
    pending = []
    for i = 0 to urls.Count() - 1
        results.Push({ ok: false, code: 0, body: "", json: invalid })
        pending.Push(i)
    end for
    for attempt = 1 to attempts
        if pending.Count() = 0 then exit for
        port = CreateObject("roMessagePort")
        started = {}
        reqs = []
        retry = []
        for each i in pending
            req = HttpNewGet(urls[i], headers, port)
            if req.AsyncGetToString() then
                started[req.GetIdentity().ToStr()] = i
                reqs.Push(req)
            else
                retry.Push(i)
            end if
        end for
        clock = CreateObject("roTimespan")
        while started.Count() > 0
            left = timeoutMs - clock.TotalMilliseconds()
            if left <= 0 then exit while
            msg = wait(left, port)
            if type(msg) <> "roUrlEvent" then exit while
            key = msg.GetSourceIdentity().ToStr()
            if started.DoesExist(key) then
                i = started[key]
                started.Delete(key)
                r = results[i]
                r.code = msg.GetResponseCode()
                r.body = msg.GetString()
                if r.code >= 200 and r.code < 300 then
                    r.json = ParseJson(r.body)
                    r.ok = r.json <> invalid
                else if r.code < 400 or r.code >= 500 then
                    retry.Push(i)
                end if
            end if
        end while
        ' Lo que no respondió a tiempo se cancela y se reintenta.
        for each key in started
            results[started[key]].code = -1
            retry.Push(started[key])
        end for
        for each req in reqs
            req.AsyncCancel()
        end for
        pending = retry
    end for
    return results
end function

' Texto de error para el usuario según el resultado HTTP.
function HttpErrorText(r as object) as string
    if r.code <= 0 then return Tx("err_network")
    if r.code = 401 or r.code = 403 then return Tx("err_auth")
    if r.code = 404 then return Tx("err_notfound")
    return Tx("err_server", r.code.ToStr())
end function

' Codifica un texto para usarlo en una URL.
function UrlEncode(s as string) as string
    return CreateObject("roUrlTransfer").Escape(s)
end function

function ApiFail(res as object, text as string) as object
    res.ok = false
    res.error = text
    return res
end function

' Punto de entrada: req = { kind, reqId, settings, ... }. Devuelve { ok, error, kind, reqId, data }.
function ApiExecute(req as object) as object
    res = { ok: false, error: "", kind: NzStr(req.kind), reqId: req.reqId, data: invalid }
    kind = res.kind
    if kind = "home" then return ApiHome(req, res)
    if kind = "search" then return ApiSearch(req, res)
    if kind = "detail" then return ApiDetail(req, res)
    if kind = "season" then return ApiSeason(req, res)
    if kind = "streams" then return ApiStreams(req, res)
    if kind = "subtitles" then return ApiSubtitles(req, res)
    return ApiFail(res, "kind?")
end function

' ---------- catálogo ----------

function ApiHome(req as object, res as object) as object
    s = req.settings
    rows = []
    if SettingsCatalogProvider(s) = "tmdb" then
        lang = TmdbLanguage(s.uiLang)
        hdr = TmdbHeaders(s.tmdbKey)
        failure = ""
        for each row in TmdbHomeRows()
            r = HttpGet(TmdbUrl(row.path, lang, s.tmdbKey, ""), hdr, 15000)
            if r.ok then
                items = TmdbParseList(r.json, row.type)
                if items.Count() > 0 then rows.Push({ title: Tx(row.title), items: items })
            else
                failure = HttpErrorText(r)
            end if
        end for
        if rows.Count() = 0 then return ApiFail(res, failure)
    else
        failure = ""
        movies = HttpGet(CinemetaListUrl("movie"), invalid, 15000)
        series = HttpGet(CinemetaListUrl("series"), invalid, 15000)
        if movies.ok then
            items = CinemetaParseList(movies.json, "movie")
            if items.Count() > 0 then rows.Push({ title: Tx("home_popular_movies"), items: items })
        else
            failure = HttpErrorText(movies)
        end if
        if series.ok then
            items = CinemetaParseList(series.json, "series")
            if items.Count() > 0 then rows.Push({ title: Tx("home_popular_series"), items: items })
        else
            failure = HttpErrorText(series)
        end if
        if rows.Count() = 0 then return ApiFail(res, failure)
    end if
    ' Se limita cada fila para no gastar memoria con imágenes.
    for each row in rows
        if row.items.Count() > 30 then
            trimmed = []
            for i = 0 to 29
                trimmed.Push(row.items[i])
            end for
            row.items = trimmed
        end if
    end for
    res.ok = true
    res.data = { rows: rows }
    return res
end function

function ApiSearch(req as object, res as object) as object
    s = req.settings
    q = NzStr(req.query).Trim()
    if q = "" then
        res.ok = true
        res.data = { items: [] }
        return res
    end if
    enc = UrlEncode(q)
    items = []
    if SettingsCatalogProvider(s) = "tmdb" then
        url = TmdbUrl("search/multi", TmdbLanguage(s.uiLang), s.tmdbKey, "query=" + enc + "&include_adult=false")
        r = HttpGet(url, TmdbHeaders(s.tmdbKey), 15000)
        if not r.ok then return ApiFail(res, HttpErrorText(r))
        items = TmdbParseSearch(r.json)
    else
        movies = HttpGet(CinemetaSearchUrl("movie", enc), invalid, 15000)
        series = HttpGet(CinemetaSearchUrl("series", enc), invalid, 15000)
        if not movies.ok and not series.ok then return ApiFail(res, HttpErrorText(movies))
        if movies.ok then
            for each it in CinemetaParseList(movies.json, "movie")
                items.Push(it)
            end for
        end if
        if series.ok then
            for each it in CinemetaParseList(series.json, "series")
                items.Push(it)
            end for
        end if
    end if
    res.ok = true
    res.data = { items: items }
    return res
end function

' Id de TMDB de un título con id de IMDb (find/…).
function TmdbResolveId(s as object, mediaType as string, imdbId as string) as integer
    url = TmdbUrl("find/" + imdbId, "", s.tmdbKey, "external_source=imdb_id")
    r = HttpGet(url, TmdbHeaders(s.tmdbKey), 15000)
    if not r.ok then return 0
    key = "movie_results"
    if mediaType = "series" then key = "tv_results"
    if type(r.json) = "roAssociativeArray" then
        if type(r.json[key]) = "roArray" then
            if r.json[key].Count() > 0 then return ToInt(r.json[key][0].id)
        end if
    end if
    return 0
end function

function ApiDetail(req as object, res as object) as object
    s = req.settings
    item = req.item
    mediaType = NzStr(item.type, "movie")
    hasImdb = Left(NzStr(item.id), 2) = "tt"
    useTmdb = SettingsCatalogProvider(s) = "tmdb"
    ' Un título que solo tiene id de TMDB únicamente puede consultarse en TMDB.
    if not hasImdb and ToInt(item.tmdbId) > 0 and s.tmdbKey <> "" then useTmdb = true
    if not useTmdb and not hasImdb then return ApiFail(res, Tx("err_noimdb"))

    if useTmdb then
        tmdbId = ToInt(item.tmdbId)
        if tmdbId = 0 then tmdbId = TmdbResolveId(s, mediaType, item.id)
        if tmdbId = 0 then return ApiFail(res, Tx("err_notfound"))
        seg = "movie"
        if mediaType = "series" then seg = "tv"
        lang = TmdbLanguage(s.uiLang)
        extra = "append_to_response=external_ids,credits"
        r = HttpGet(TmdbUrl(seg + "/" + tmdbId.ToStr(), lang, s.tmdbKey, extra), TmdbHeaders(s.tmdbKey), 15000)
        if not r.ok then return ApiFail(res, HttpErrorText(r))
        detail = TmdbParseDetail(r.json, mediaType)
        if detail = invalid then return ApiFail(res, Tx("err_notfound"))
        ' Episodios de la primera temporada para pintar la ficha completa.
        if mediaType = "series" and detail.seasons.Count() > 0 then
            first = detail.seasons[0]
            for each cand in detail.seasons
                if cand.number > 0 then
                    first = cand
                    exit for
                end if
            end for
            sr = HttpGet(TmdbUrl("tv/" + tmdbId.ToStr() + "/season/" + first.number.ToStr(), lang, s.tmdbKey, ""), TmdbHeaders(s.tmdbKey), 15000)
            if sr.ok then first.episodes = TmdbParseEpisodes(sr.json, first.number)
        end if
    else
        r = HttpGet(CinemetaMetaUrl(mediaType, item.id), invalid, 15000)
        if not r.ok then return ApiFail(res, HttpErrorText(r))
        detail = CinemetaParseDetail(r.json, mediaType)
        if detail = invalid then return ApiFail(res, Tx("err_notfound"))
    end if
    ' Conserva lo que ya sabíamos si la ficha viene incompleta.
    if detail.poster = "" then detail.poster = NzStr(item.poster)
    if detail.backdrop = "" then detail.backdrop = NzStr(item.backdrop)
    if detail.description = "" then detail.description = NzStr(item.description)
    res.ok = true
    res.data = detail
    return res
end function

' Episodios de una temporada de TMDB.
function ApiSeason(req as object, res as object) as object
    s = req.settings
    tmdbId = ToInt(req.tmdbId)
    if tmdbId = 0 then return ApiFail(res, Tx("err_notfound"))
    n = ToInt(req.season)
    url = TmdbUrl("tv/" + tmdbId.ToStr() + "/season/" + n.ToStr(), TmdbLanguage(s.uiLang), s.tmdbKey, "")
    r = HttpGet(url, TmdbHeaders(s.tmdbKey), 15000)
    if not r.ok then return ApiFail(res, HttpErrorText(r))
    res.ok = true
    res.data = { season: n, episodes: TmdbParseEpisodes(r.json, n) }
    return res
end function

' ---------- fuentes y subtítulos ----------

' Id de video de Stremio: "tt123" o "tt123:temporada:episodio".
function VideoId(imdbId as string, season as integer, episode as integer) as string
    if season < 0 or episode < 0 then return imdbId
    return imdbId + ":" + season.ToStr() + ":" + episode.ToStr()
end function

' Consulta todos los addons de fuentes (los del usuario y los del plugin) a la vez, junta lo que reproduce Roku
' (solo enlaces http/https), quita repetidos y ordena. Un addon que falla se omite; si fallan todos, es un error.
function ApiStreams(req as object, res as object) as object
    s = req.settings
    bases = AddonsEffective(s)
    if bases.Count() = 0 then return ApiFail(res, Tx("src_noaddons"))
    id = VideoId(req.imdbId, ToInt(req.season, -1), ToInt(req.episode, -1))
    urls = []
    for each b in bases
        urls.Push(AddonStreamUrl(b, req.mediaType, id))
    end for
    results = HttpGetMany(urls, invalid, 25000)
    all = []
    total = 0
    anyOk = false
    firstFail = invalid
    for i = 0 to results.Count() - 1
        r = results[i]
        if r.ok then
            anyOk = true
            if type(r.json) = "roAssociativeArray" then
                if type(r.json.streams) = "roArray" then
                    for each raw in r.json.streams
                        total = total + 1
                        c = StreamParse(raw, bases[i])
                        if c <> invalid then all.Push(PluginStreamEnrich(c, raw, s))
                    end for
                end if
            end if
        else if firstFail = invalid then
            firstFail = r
        end if
    end for
    if not anyOk then return ApiFail(res, HttpErrorText(firstFail))
    playable = StreamsDedupe(StreamsPlayableOnly(all))
    ' Algunos addons mezclan remakes bajo el mismo id: en películas con año conocido se descartan los de otro año.
    if req.mediaType = "movie" and ToInt(req.year) > 0 then playable = StreamsDropOtherYears(playable, ToInt(req.year))
    if playable.Count() = 0 then
        ' Si el addon solo devolvió avisos (clave inválida, cuenta sin acceso), se explica el motivo.
        for each c in all
            if c.notice = true then return ApiFail(res, Tx("err_auth"))
        end for
    end if
    ranked = StreamsRank(playable, s.prefLangs, s.maxQuality)
    limited = []
    for each c in ranked
        if limited.Count() < 40 then limited.Push(c)
    end for
    res.ok = true
    res.data = { sources: limited, total: total }
    return res
end function

' Convierte la respuesta del addon de subtítulos en pistas { url, language (ISO 639-2), label }.
function SubtitlesParse(json as dynamic) as object
    result = []
    if type(json) <> "roAssociativeArray" then return result
    if type(json.subtitles) <> "roArray" then return result
    for each sub_ in json.subtitles
        if type(sub_) = "roAssociativeArray" then
            url = NzStr(sub_.url)
            lang = NzStr(sub_.lang)
            if url <> "" and lang <> "" then result.Push({ url: url, language: LCase(lang), label: SubLangName(lang) })
        end if
    end for
    return result
end function

' Filtra por idiomas deseados (ISO 639-2, en orden de preferencia), conserva ese orden, limita a perLanguage por
' idioma y numera las etiquetas repetidas ("Español 2").
function SubtitlesFilter(tracks as object, wanted as object, perLanguage = 3 as integer) as object
    result = []
    for each w in wanted
        count = 0
        for each t in tracks
            if SubLangSame(t.language, w) and count < perLanguage and not SubtitlesContains(result, t.url) then
                label = t.label
                if count > 0 then label = label + " " + (count + 1).ToStr()
                result.Push({ url: t.url, language: t.language, label: label })
                count = count + 1
            end if
        end for
    end for
    return result
end function

function SubtitlesContains(list as object, url as string) as boolean
    for each t in list
        if t.url = url then return true
    end for
    return false
end function

' Pistas de subtítulos de todos los addons configurados: se consultan a la vez, se juntan, se filtran por idioma y
' se quitan repetidas. Un addon que falla se omite en silencio; si todos fallan se reproduce sin subtítulos.
function ApiSubtitles(req as object, res as object) as object
    s = req.settings
    res.ok = true
    res.data = { tracks: [] }
    if s.subLangs.Count() = 0 or s.subAddons.Count() = 0 then return res
    id = VideoId(req.imdbId, ToInt(req.season, -1), ToInt(req.episode, -1))
    urls = []
    for each b in s.subAddons
        urls.Push(AddonSubtitlesUrl(b, req.mediaType, id))
    end for
    tracks = []
    for each r in HttpGetMany(urls, invalid, 8000, 1)
        if r.ok then
            for each t in SubtitlesParse(r.json)
                tracks.Push(t)
            end for
        end if
    end for
    res.data = { tracks: SubtitlesFilter(tracks, s.subLangs) }
    return res
end function
