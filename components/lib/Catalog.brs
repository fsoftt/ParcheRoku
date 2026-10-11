' Catálogos Cinemeta (sin clave) y TMDB (con clave opcional): URLs y análisis del JSON.
' Todo son funciones puras (el acceso a red está en Api.brs).
'
' Un "título" (item) es un AA: { id (IMDb "tt…" o ""), tmdbId (0 si no hay), type ("movie"|"series"), title, year,
'                                poster, backdrop, description, rating (0 si no hay), genres[] }
' Una "ficha" (detail) es un título más: runtime (min), cast[], seasons[] ({number, title, episodes[]|invalid}), trailer.
' Un episodio: { season, number, title, overview, thumbnail, released }

function CinemetaCatalogBase() as string
    return "https://v3-cinemeta.strem.io"
end function

function CinemetaMetaBase() as string
    return "https://cinemeta-live.strem.io"
end function

function TmdbApiBase() as string
    return "https://api.themoviedb.org/3"
end function

function TmdbPosterBase() as string
    return "https://image.tmdb.org/t/p/w342"
end function

function TmdbBackdropBase() as string
    return "https://image.tmdb.org/t/p/w1280"
end function

function TmdbStillBase() as string
    return "https://image.tmdb.org/t/p/w300"
end function

' ---------- utilidades ----------

' Año a partir de "1969", "2019-2023", "2019-05-02"…; 0 si no se puede.
function ParseYear(v as dynamic) as integer
    s = NzStr(v)
    if Len(s) < 4 then return 0
    y = Int(Val(Left(s, 4)))
    if y < 1800 then return 0
    return y
end function

' Minutos a partir de "142 min" / "142".
function ParseRuntime(v as dynamic) as integer
    s = NzStr(v)
    digits = ""
    for i = 1 to Len(s)
        ch = Mid(s, i, 1)
        if ch >= "0" and ch <= "9" then
            digits = digits + ch
        else
            exit for
        end if
    end for
    if digits = "" then return 0
    return Int(Val(digits))
end function

function StrArray(v as dynamic) as object
    out = []
    if type(v) = "roArray" then
        for each x in v
            if IsStr(x) then out.Push(x)
        end for
    end if
    return out
end function

' ---------- Cinemeta ----------

function CinemetaListUrl(mediaType as string) as string
    return CinemetaCatalogBase() + "/catalog/" + mediaType + "/top.json"
end function

' query ya debe venir codificado para URL.
function CinemetaSearchUrl(mediaType as string, encodedQuery as string) as string
    return CinemetaCatalogBase() + "/catalog/" + mediaType + "/top/search=" + encodedQuery + ".json"
end function

function CinemetaMetaUrl(mediaType as string, id as string) as string
    return CinemetaMetaBase() + "/meta/" + mediaType + "/" + id + ".json"
end function

' "movie" | "series" según el tipo de Stremio ("tv" cuenta como serie).
function MediaTypeFrom(t as dynamic) as string
    s = LCase(NzStr(t))
    if s = "series" or s = "tv" then return "series"
    return "movie"
end function

function CinemetaParseItem(meta as dynamic, fallbackType as string) as dynamic
    if type(meta) <> "roAssociativeArray" then return invalid
    title = NzStr(meta.name)
    if title = "" then return invalid
    id = NzStr(meta.imdb_id)
    if id = "" then id = NzStr(meta.id)
    year = ParseYear(meta.year)
    if year = 0 then year = ParseYear(meta.releaseInfo)
    genres = StrArray(meta.genres)
    if genres.Count() = 0 then genres = StrArray(meta.genre)
    t = fallbackType
    if meta.type <> invalid then t = MediaTypeFrom(meta.type)
    return {
        id: id
        tmdbId: ToInt(meta.moviedb_id)
        type: t
        title: title
        year: year
        poster: NzStr(meta.poster)
        backdrop: NzStr(meta.background)
        description: NzStr(meta.description)
        rating: ToFloat(meta.imdbRating)
        genres: genres
    }
end function

function CinemetaParseList(json as dynamic, mediaType as string) as object
    result = []
    if type(json) <> "roAssociativeArray" then return result
    if type(json.metas) <> "roArray" then return result
    for each meta in json.metas
        it = CinemetaParseItem(meta, mediaType)
        if it <> invalid then result.Push(it)
    end for
    return result
end function

function SeasonTitle(n as integer) as string
    if n = 0 then return Tx("det_specials")
    return Tx("det_season", n)
end function

' Ficha de Cinemeta (json = { meta: {...} }); invalid si no hay ficha.
function CinemetaParseDetail(json as dynamic, mediaType as string) as dynamic
    if type(json) <> "roAssociativeArray" then return invalid
    meta = json.meta
    item = CinemetaParseItem(meta, mediaType)
    if item = invalid then return invalid
    item.runtime = ParseRuntime(meta.runtime)
    cast = []
    for each c in StrArray(meta.cast)
        if cast.Count() < 8 then cast.Push(c)
    end for
    item.cast = cast
    item.trailer = ""
    item.seasons = []
    if item.type = "series" then item.seasons = CinemetaParseSeasons(meta)
    return item
end function

' Agrupa meta.videos por temporada: ascendentes, con la 0 (especiales) al final.
function CinemetaParseSeasons(meta as object) as object
    bySeason = {}
    numbers = []
    if type(meta.videos) = "roArray" then
        for each v in meta.videos
            if type(v) = "roAssociativeArray" and IsNum(v.season) then
                num = v.episode
                if not IsNum(num) then num = v.number
                if IsNum(num) then
                    key = Int(v.season).ToStr()
                    if not bySeason.DoesExist(key) then
                        bySeason[key] = []
                        numbers.Push(Int(v.season))
                    end if
                    title = NzStr(v.name)
                    if title = "" then title = NzStr(v.title)
                    if title = "" then title = Tx("det_episode", Int(num))
                    overview = NzStr(v.overview)
                    if overview = "" then overview = NzStr(v.description)
                    bySeason[key].Push({
                        season: Int(v.season)
                        number: Int(num)
                        title: title
                        overview: overview
                        thumbnail: NzStr(v.thumbnail)
                        released: Left(NzStr(v.released), 10)
                    })
                end if
            end if
        end for
    end if
    numbers.Sort()
    ordered = []
    hasZero = false
    for each n in numbers
        if n = 0 then
            hasZero = true
        else
            ordered.Push(n)
        end if
    end for
    if hasZero then ordered.Push(0)

    seasons = []
    for each n in ordered
        eps = SortEpisodes(bySeason[n.ToStr()])
        seasons.Push({ number: n, title: SeasonTitle(n), episodes: eps })
    end for
    return seasons
end function

' Ordena episodios por número (inserción, estable).
function SortEpisodes(eps as object) as object
    items = []
    for each e in eps
        items.Push(e)
    end for
    for i = 1 to items.Count() - 1
        cur = items[i]
        j = i - 1
        while j >= 0
            if cur.number < items[j].number then
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

' ---------- TMDB ----------

' La clave v3 son 32 hex; el token v4 es un JWT ("eyJ…", mucho más largo).
function TmdbIsBearer(key as string) as boolean
    if Left(key, 3) = "eyJ" then return true
    if Len(key) > 40 then return true
    if Instr(1, key, ".") > 0 then return true
    return false
end function

' URL de TMDB con idioma y, si la clave es v3, api_key. extra: "k=v&k2=v2" ya codificado (o "").
function TmdbUrl(path as string, lang as string, key as string, extra as string) as string
    parts = []
    if lang <> "" then parts.Push("language=" + lang)
    if extra <> "" then parts.Push(extra)
    if not TmdbIsBearer(key) then parts.Push("api_key=" + key)
    return TmdbApiBase() + "/" + path + "?" + ArrayJoin(parts, "&")
end function

' Cabeceras de TMDB (Bearer para tokens v4).
function TmdbHeaders(key as string) as object
    if TmdbIsBearer(key) then return { Authorization: "Bearer " + key }
    return {}
end function

' Idioma de TMDB según el idioma de la interfaz.
function TmdbLanguage(uiLang as string) as string
    if uiLang = "en" then return "en-US"
    if uiLang = "pt" then return "pt-BR"
    return "es-ES"
end function

' Filas de la portada de TMDB: ruta, tipo y clave de traducción del título.
function TmdbHomeRows() as object
    return [
        { path: "trending/movie/week", type: "movie", title: "home_trending_movies" }
        { path: "trending/tv/week", type: "series", title: "home_trending_series" }
        { path: "movie/popular", type: "movie", title: "home_popular_movies" }
        { path: "tv/popular", type: "series", title: "home_popular_series" }
        { path: "movie/top_rated", type: "movie", title: "home_top_movies" }
        { path: "tv/top_rated", type: "series", title: "home_top_series" }
    ]
end function

function TmdbParseItem(r as dynamic, mediaType as string) as dynamic
    if type(r) <> "roAssociativeArray" then return invalid
    title = NzStr(r.title)
    if title = "" then title = NzStr(r.name)
    id = ToInt(r.id)
    if title = "" or id = 0 then return invalid
    date = NzStr(r.release_date)
    if date = "" then date = NzStr(r.first_air_date)
    poster = ""
    if NzStr(r.poster_path) <> "" then poster = TmdbPosterBase() + r.poster_path
    backdrop = ""
    if NzStr(r.backdrop_path) <> "" then backdrop = TmdbBackdropBase() + r.backdrop_path
    rating = ToFloat(r.vote_average)
    return {
        id: ""
        tmdbId: id
        type: mediaType
        title: title
        year: ParseYear(date)
        poster: poster
        backdrop: backdrop
        description: NzStr(r.overview)
        rating: rating
        genres: []
    }
end function

function TmdbParseList(json as dynamic, mediaType as string) as object
    result = []
    if type(json) <> "roAssociativeArray" then return result
    if type(json.results) <> "roArray" then return result
    for each r in json.results
        it = TmdbParseItem(r, mediaType)
        if it <> invalid then result.Push(it)
    end for
    return result
end function

' Resultados de search/multi (películas y series).
function TmdbParseSearch(json as dynamic) as object
    result = []
    if type(json) <> "roAssociativeArray" then return result
    if type(json.results) <> "roArray" then return result
    for each r in json.results
        if type(r) = "roAssociativeArray" then
            mt = NzStr(r.media_type)
            if mt = "movie" or mt = "tv" then
                t = "movie"
                if mt = "tv" then t = "series"
                it = TmdbParseItem(r, t)
                if it <> invalid then result.Push(it)
            end if
        end if
    end for
    return result
end function

function TmdbParseEpisodes(json as dynamic, seasonNumber as integer) as object
    eps = []
    if type(json) <> "roAssociativeArray" then return eps
    if type(json.episodes) <> "roArray" then return eps
    for each e in json.episodes
        if type(e) = "roAssociativeArray" then
            num = ToInt(e.episode_number)
            title = NzStr(e.name)
            if title = "" then title = Tx("det_episode", num)
            thumb = ""
            if NzStr(e.still_path) <> "" then thumb = TmdbStillBase() + e.still_path
            eps.Push({
                season: ToInt(e.season_number, seasonNumber)
                number: num
                title: title
                overview: NzStr(e.overview)
                thumbnail: thumb
                released: NzStr(e.air_date)
            })
        end if
    end for
    return SortEpisodes(eps)
end function

' Ficha de TMDB (con append_to_response=external_ids,credits,videos). Las temporadas vienen sin episodios
' (episodes = invalid) y se piden luego con la ruta tv/{id}/season/{n}.
function TmdbParseDetail(json as dynamic, mediaType as string) as dynamic
    item = TmdbParseItem(json, mediaType)
    if item = invalid then return invalid
    imdb = ""
    if type(json.external_ids) = "roAssociativeArray" then imdb = NzStr(json.external_ids.imdb_id)
    if imdb = "" then imdb = NzStr(json.imdb_id)
    item.id = imdb

    genres = []
    if type(json.genres) = "roArray" then
        for each g in json.genres
            if type(g) = "roAssociativeArray" then
                if NzStr(g.name) <> "" then genres.Push(g.name)
            end if
        end for
    end if
    item.genres = genres

    runtime = ToInt(json.runtime)
    if runtime = 0 and type(json.episode_run_time) = "roArray" then
        if json.episode_run_time.Count() > 0 then runtime = ToInt(json.episode_run_time[0])
    end if
    item.runtime = runtime

    cast = []
    if type(json.credits) = "roAssociativeArray" then
        if type(json.credits.cast) = "roArray" then
            for each c in json.credits.cast
                if type(c) = "roAssociativeArray" and cast.Count() < 8 then
                    if NzStr(c.name) <> "" then cast.Push(c.name)
                end if
            end for
        end if
    end if
    item.cast = cast
    item.trailer = ""

    seasons = []
    if mediaType = "series" and type(json.seasons) = "roArray" then
        zero = invalid
        for each s in json.seasons
            if type(s) = "roAssociativeArray" and IsNum(s.season_number) then
                n = Int(s.season_number)
                title = NzStr(s.name)
                if title = "" then title = SeasonTitle(n)
                entry = { number: n, title: title, episodes: invalid }
                if n = 0 then
                    zero = entry
                else
                    seasons.Push(entry)
                end if
            end if
        end for
        if zero <> invalid then seasons.Push(zero)
    end if
    item.seasons = seasons
    return item
end function
