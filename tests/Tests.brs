' Pruebas unitarias de la lógica pura (ranking, análisis de fuentes, addons, ajustes, historial, catálogos).
' Se ejecutan fuera del dispositivo con el intérprete "brs" de Node: npm test (ver tests/run.js).

' Pruebas que valen con cualquier Plugins.brs (el neutro o uno real).
sub RunPublicTests()
    TestUtil()
    TestLanguage()
    TestParser()
    TestRanker()
    TestLanguageFilter()
    TestDescribe()
    TestAddons()
    TestContinueWatching()
    TestMyList()
    TestCatalog()
    TestSubtitles()
    TestSettings()
    TestMovieYears()
end sub

sub TestUtil()
    Eq("FormatSize GB", FormatSize(2254857830#), "2.1 GB")
    Eq("FormatSize MB", FormatSize(734003200#), "700 MB")
    Eq("FormatSize 0", FormatSize(0#), "")
    Eq("ToInt cadena", ToInt("42"), 42)
    Eq("ToInt invalid", ToInt(invalid, 7), 7)
    Eq("ArrayJoin", ArrayJoin(["a", "b", "c"], ", "), "a, b, c")
    Eq("FormatArgs", FormatArgs("T%1 E%2", 1, 5), "T1 E5")
    Eq("ItemKey imdb", ItemKey({ id: "tt0063350", type: "movie" }), "tt0063350")
    Eq("ItemKey tmdb", ItemKey({ id: "", tmdbId: 12, type: "series" }), "tmdb:series:12")
    Eq("Fmt1", Fmt1(8.44#), "8.4")
    Eq("Tx es", Tx("nav_home"), "Inicio")
    Eq("Tx args", Tx("home_s_e", 2, 3), "T2 E3")
    Eq("Tx falta", Tx("no_existe"), "no_existe")
end sub

sub TestLanguage()
    Eq("Detect latino", LangDetect("Movie 1080p LATINO"), ["es-419"])
    Eq("Detect castellano", LangDetect("Pelicula CASTELLANO"), ["es"])
    Eq("Detect dual", LangDetect("Movie DUAL 1080p"), ["multi"])
    Eq("Detect ingles por defecto", LangDetect("Movie 1080p"), ["en"])
    Eq("Detect varios", LangDetect("Movie ESP LAT ENG"), ["es-419", "es", "en"])
    Eq("Detect no confunde palabras", LangDetect("Latitude Spanky"), ["en"])
    Eq("Matches es-419", LangMatches("es", "es-419"), true)
    Eq("Matches es-419 estricto", LangMatches("es-419", "es"), false)
    Eq("Sub iso1", SubLangToIso1("spa"), "es")
    Eq("Sub mismo idioma", SubLangSame("spa", "es"), true)
end sub

sub TestContinueWatching()
    list = []
    list = CwReport(list, Entry("tt1", -1, -1, 120000, 6000000, 1))
    Eq("agrega", list.Count(), 1)
    list = CwReport(list, Entry("tt2", -1, -1, 300000, 6000000, 2))
    Eq("mas reciente primero", list[0].item.id, "tt2")
    list = CwReport(list, Entry("tt1", -1, -1, 900000, 6000000, 3))
    Eq("una entrada por titulo", list.Count(), 2)
    Eq("la actualizada sube", list[0].item.id, "tt1")
    Eq("posicion actualizada", list[0].positionMs, 900000)
    list = CwReport(list, Entry("tt3", -1, -1, 30000, 6000000, 4))
    Eq("ignora menos de un minuto", list.Count(), 2)
    list = CwReport(list, Entry("tt1", -1, -1, 5600000, 6000000, 5))
    Eq("terminada se quita", list.Count(), 1)
    Eq("queda la otra", list[0].item.id, "tt2")
    Eq("fraccion", Int(CwFraction(list[0]) * 100), 5)
    ep = CwReport([], Entry("tt9", 1, 4, 100000, 3000000, 6))
    Eq("find episodio", CwFind(ep, { id: "tt9", tmdbId: 0, type: "series" }, 1, 4) <> invalid, true)
    Eq("find otro episodio", CwFind(ep, { id: "tt9", tmdbId: 0, type: "series" }, 1, 5), invalid)
    Eq("no identificable", CwReport([], { item: { id: "", tmdbId: 0, type: "movie", title: "x" }, positionMs: 100000, durationMs: 1000000 }).Count(), 0)
    big = []
    for n = 1 to 20
        big = CwReport(big, Entry("tt" + n.ToStr(), -1, -1, 100000, 6000000, n))
    end for
    Eq("maximo de entradas", big.Count(), 15)
    Eq("conserva las mas recientes", big[0].item.id, "tt20")
end sub

sub TestMyList()
    item = { id: "tt1", tmdbId: 0, type: "movie", title: "Uno", description: "no se guarda" }
    list = MlToggle([], item)
    Eq("agrega a mi lista", list.Count(), 1)
    Eq("compacta (sin descripcion)", list[0].DoesExist("description"), false)
    Eq("contiene", MlContains(list, item), true)
    list = MlToggle(list, item)
    Eq("quita al repetir", list.Count(), 0)
end sub

sub TestCatalog()
    Eq("anio", ParseYear("2019-2023"), 2019)
    Eq("duracion", ParseRuntime("142 min"), 142)
    meta = {
        id: "tt1", imdb_id: "tt1", name: "Serie", type: "series", year: "2008", genres: ["Drama"], imdbRating: "8.1"
        videos: [
            { season: 2, episode: 1, name: "B1" }
            { season: 1, episode: 2, name: "A2" }
            { season: 0, episode: 1, name: "Esp" }
            { season: 1, episode: 1, name: "A1" }
        ]
    }
    d = CinemetaParseDetail({ meta: meta }, "series")
    Eq("detalle titulo", d.title, "Serie")
    Eq("detalle rating", d.rating, 8.1)
    Eq("temporadas ordenadas (0 al final)", [d.seasons[0].number, d.seasons[1].number, d.seasons[2].number], [1, 2, 0])
    Eq("episodios ordenados", [d.seasons[0].episodes[0].title, d.seasons[0].episodes[1].title], ["A1", "A2"])
    Eq("titulo de especiales", d.seasons[2].title, "Especiales")
    Eq("lista cinemeta", CinemetaParseList({ metas: [{ id: "tt2", name: "X" }, { id: "tt3" }] }, "movie").Count(), 1)
    t = TmdbParseItem({ id: 5, title: "Peli", release_date: "2001-05-02", poster_path: "/p.jpg", vote_average: 7.5 }, "movie")
    Eq("tmdb item", t.tmdbId, 5)
    Eq("tmdb poster", t.poster, "https://image.tmdb.org/t/p/w342/p.jpg")
    Eq("tmdb anio", t.year, 2001)
    Eq("tmdb v3 url", TmdbUrl("movie/popular", "es-ES", "abc", ""), "https://api.themoviedb.org/3/movie/popular?language=es-ES&api_key=abc")
    Eq("tmdb v4 url sin api_key", Instr(1, TmdbUrl("movie/popular", "es-ES", "eyJabc.def.ghi", ""), "api_key"), 0)
    Eq("tmdb bearer", TmdbIsBearer("eyJhbGciOi"), true)
    Eq("tmdb v3 no bearer", TmdbIsBearer("0123456789abcdef0123456789abcdef"), false)
    Eq("cinemeta busqueda", CinemetaSearchUrl("movie", "star%20wars"), "https://v3-cinemeta.strem.io/catalog/movie/top/search=star%20wars.json")
end sub

sub TestParser()
    s = StreamParse(MakeStream("Addon" + Chr(10) + "1080p", "Movie.2020.1080p.BluRay.x264" + Chr(10) + "2.1 GB", "https://cdn.example/Movie.mkv"), "a")
    Eq("parse calidad", s.quality, "1080p")
    Eq("parse tamano", Int(s.sizeBytes / 1048576), 2150)
    Eq("parse etiquetas", s.tags, ["bluray"])
    Eq("parse archivo", s.fileName, "Movie.2020.1080p.BluRay.x264")
    Eq("parse prioridad por defecto", s.priority, 0)
    Eq("parse no es aviso", s.notice, false)

    u = StreamParse(MakeStream("Addon" + Chr(10) + "4k", "Movie.2160p.REMUX.HDR" + Chr(10) + "40 GB", "https://x/y.mkv"), "a")
    Eq("parse 4k", u.quality, "2160p")
    Eq("parse remux+hdr", u.tags, ["remux", "hdr"])
    Eq("parse tamano 40 GB", Int(u.sizeBytes / 1073741824), 40)

    hint = StreamParse({ name: "A", title: "x", url: "https://x/z.mkv", behaviorHints: { filename: "Real.Name.mkv", videoSize: 1048576 } }, "a")
    Eq("parse archivo de behaviorHints", hint.fileName, "Real.Name.mkv")
    Eq("parse tamano de behaviorHints", hint.sizeBytes, 1048576)
    hdr = StreamParse({ name: "A", url: "https://x/z.mkv", behaviorHints: { proxyHeaders: { request: { Referer: "https://r" } } } }, "a")
    Eq("parse cabeceras", hdr.headers.Referer, "https://r")

    Eq("sin url no sirve", StreamParse({ name: "x", infoHash: "abc" }, "a"), invalid)
    Eq("url que no es http no sirve", StreamParse({ name: "x", url: "acestream://abc" }, "a"), invalid)
    Eq("url ftp no sirve", StreamParse({ name: "x", url: "ftp://a/b" }, "a"), invalid)
    Eq("sin url", StreamParse({ name: "x" }, "a"), invalid)

    json = ParseJson("{""streams"":[{""name"":""T"",""title"":""A 1080p"",""url"":""https://a/b.mkv""},{""name"":""T"",""url"":""acestream://aa""}]}")
    Eq("ParseResponse descarta lo que no es http", StreamsParseResponse(json, "t").Count(), 1)
    Eq("Dedupe", StreamsDedupe([s, s]).Count(), 1)
    Eq("Calidad SD", StreamDetectQuality("Movie DVDRip"), "480p")
    Eq("Calidad sin dato", StreamDetectQuality("Movie"), "SD")
    Eq("Audio 5.1", StreamReleaseTags("Movie 1080p WEB-DL DDP5.1"), ["web", "5.1"])
    Eq("Formato mkv", GuessStreamFormat("https://a/b/Movie.mkv?x=1"), "mkv")
    Eq("Formato hls", GuessStreamFormat("https://a/index.m3u8"), "hls")
    Eq("Formato desconocido", GuessStreamFormat("https://a/video"), "")
    Eq("playable descarta avisos", StreamsPlayableOnly([{ url: "https://t/a.mkv", notice: true }, { url: "https://t/b.mkv", notice: false }, { url: "https://t/c.mkv" }]).Count(), 2)
    Eq("tamano: no confunde 5.1", StreamParseSize("Movie DDP5.1 GB"), 0#)
    Eq("tamano: coma decimal", Int(StreamParseSize("700,5 MB") / 1048576), 700)
    Eq("VideoId pelicula", VideoId("tt1", -1, -1), "tt1")
    Eq("VideoId episodio", VideoId("tt1", 2, 3), "tt1:2:3")
end sub

sub TestRanker()
    a = Cand("a", "1080p", 0, ["en"], 2)
    b = Cand("b", "720p", 500, ["en"], 1)
    c = Cand("c", "1080p", 1000000, ["en"], 2)
    Eq("prioridad mayor primero", Names(StreamsRank([a, b, c])), ["c", "b", "a"])
    Eq("sin prioridad (campo ausente) cuenta como 0", Names(StreamsRank([{ name: "x", title: "x", quality: "1080p", languages: ["en"], sizeBytes: 0#, tags: [] }, b])), ["b", "x"])

    d = Cand("d", "1080p", 0, ["es"], 2)
    e = Cand("e", "1080p", 0, ["en"], 2)
    f = Cand("f", "1080p", 0, ["es-419"], 2)
    Eq("idioma desempata: Latino (es-419) antes que Castellano (es)", Names(StreamsRank([e, d, f])), ["f", "d", "e"])

    g = Cand("g", "2160p", 0, ["en"], 20)
    h = Cand("h", "1080p", 0, ["en"], 4)
    i = Cand("i", "720p", 0, ["en"], 1)
    Eq("tope de calidad 1080p", Names(StreamsRank([g, i, h])), ["h", "i", "g"])
    Eq("sin tope", Names(StreamsRank([i, h, g], invalid, "")), ["g", "h", "i"])

    j = Cand("j", "1080p", 0, ["en"], 1)
    k = Cand("k", "1080p", 0, ["en"], 5)
    Eq("tamano desempata (mayor primero)", Names(StreamsRank([j, k])), ["k", "j"])

    l = Cand("l", "1080p", 0, ["en"], 2)
    m_ = Cand("m", "1080p", 0, ["en"], 2)
    Eq("estable con empates", Names(StreamsRank([l, m_])), ["l", "m"])

    n = Cand("n", "1080p", 0, ["multi"], 2)
    o = Cand("o", "1080p", 0, ["pt"], 2)
    Eq("multi cuenta tras las preferidas", Names(StreamsRank([o, n])), ["n", "o"])
    Eq("lista vacia", StreamsRank([]).Count(), 0)
end sub

sub TestLanguageFilter()
    a = Cand("a", "1080p", 0, ["es"], 2)
    b = Cand("b", "1080p", 0, ["es-419", "en"], 2)
    c = Cand("c", "1080p", 0, ["multi"], 2)
    d = Cand("d", "1080p", 0, ["en"], 2)
    all = [a, b, c, d]
    Eq("filtro vacio devuelve todo", Names(StreamsFilterByLanguage(all, "")), ["a", "b", "c", "d"])
    Eq("filtro es explicito", Names(StreamsFilterByLanguage(all, "es")), ["a"])
    Eq("filtro latino explicito", Names(StreamsFilterByLanguage(all, "es-419")), ["b"])
    Eq("filtro en excluye multi", Names(StreamsFilterByLanguage(all, "en")), ["b", "d"])
    Eq("filtro sin coincidencias", StreamsFilterByLanguage([c], "es").Count(), 0)
    tr = [{ Track: "1", Language: "eng" }, { Track: "2", Language: "spa" }, { Track: "3", Language: "spl" }]
    Eq("audio prefiere en orden", AudioPickTrack(tr, ["es-419", "en"]), "3")
    Eq("audio es", AudioPickTrack(tr, ["es"]), "2")
    Eq("audio segunda preferencia", AudioPickTrack([tr[0]], ["es", "en"]), "1")
    Eq("audio sin coincidencia", AudioPickTrack([tr[0]], ["es"]), "")
end sub

sub TestDescribe()
    c = Cand("c", "1080p", 0, ["es-419", "en"], 2)
    c.tags = ["remux", "5.1"]
    c.provider = "YTS"
    c.availText = "Disponible"
    c.availColor = "0xFBBF24FF"
    d = StreamDescribe(c)
    bullet = " " + Chr(183) + " "
    Eq("describe linea 1", d.line1, "1080p" + bullet + "Blu-ray original" + bullet + "Audio 5.1" + bullet + "2.0 GB")
    Eq("describe linea 2", d.line2, "Origen: YTS" + bullet + "Latino, Inglés")
    Eq("describe disponibilidad del plugin", d.avail, "Disponible")
    Eq("describe color", d.availColor, "0xFBBF24FF")
    u = Cand("u", "720p", 0, ["en"], 1)
    Eq("describe sin disponibilidad", StreamDescribe(u).avail, "")
    Eq("describe sin origen", StreamDescribe(u).line2, "Inglés")
end sub

sub TestAddons()
    Eq("addon: manifest", AddonNormalizeUrl("https://a.example/cfg/manifest.json"), "https://a.example/cfg")
    Eq("addon: espacios y barra final", AddonNormalizeUrl("  https://a.example/ "), "https://a.example")
    Eq("addon: stremio://", AddonNormalizeUrl("stremio://a.example/x/manifest.json"), "https://a.example/x")
    Eq("addon: http se acepta", AddonNormalizeUrl("http://192.168.1.5:7000"), "http://192.168.1.5:7000")
    Eq("addon: sin esquema", AddonNormalizeUrl("a.example"), "")
    Eq("addon: solo esquema", AddonNormalizeUrl("https://"), "")
    Eq("addon: vacio", AddonNormalizeUrl(""), "")
    Eq("addon: ftp no", AddonNormalizeUrl("ftp://a.example"), "")
    l = AddonListAdd([], "https://a.example/manifest.json")
    l = AddonListAdd(l, "https://b.example")
    l = AddonListAdd(l, "https://a.example/")
    Eq("addon: agregar sin repetir", l, ["https://a.example", "https://b.example"])
    l = AddonListAdd(l, "basura")
    Eq("addon: basura no se agrega", l.Count(), 2)
    Eq("addon: quitar", AddonListRemove(l, 0), ["https://b.example"])
    Eq("addon: quitar fuera de rango", AddonListRemove(l, 9).Count(), 2)
    Eq("addon: limpiar", AddonListClean(["https://a.example/", "x", "https://a.example", 5, "https://b.example/manifest.json"]), ["https://a.example", "https://b.example"])
    Eq("addon: etiqueta es el dominio", AddonLabel("https://abc.example:8080/secreto/clave"), "abc.example:8080")
    Eq("addon: url de streams", AddonStreamUrl("https://a.example/cfg", "movie", "tt0063350"), "https://a.example/cfg/stream/movie/tt0063350.json")
    Eq("addon: url de streams codifica |", AddonStreamUrl("https://a.example/a=1|b=2", "series", VideoId("tt1", 2, 3)), "https://a.example/a=1%7Cb=2/stream/series/tt1:2:3.json")
    Eq("addon: url de subtitulos", AddonSubtitlesUrl("https://s.example", "movie", "tt1"), "https://s.example/subtitles/movie/tt1.json")
end sub

sub TestSubtitles()
    json = ParseJson("{""subtitles"":[{""url"":""https://s/1.srt"",""lang"":""spa""},{""url"":""https://s/2.srt"",""lang"":""eng""},{""url"":""https://s/3.srt"",""lang"":""spa""},{""url"":""https://s/4.srt"",""lang"":""fre""}]}")
    tracks = SubtitlesParse(json)
    Eq("subtitulos parseados", tracks.Count(), 4)
    f = SubtitlesFilter(tracks, ["spa", "eng"])
    Eq("filtra y ordena por preferencia", [f[0].url, f[1].url, f[2].url], ["https://s/1.srt", "https://s/3.srt", "https://s/2.srt"])
    Eq("numera repetidos", f[1].label, "Español 2")
    Eq("sin idiomas", SubtitlesFilter(tracks, []).Count(), 0)
    ' Varios addons: se juntan las pistas y se quitan las repetidas por URL.
    other = SubtitlesParse(ParseJson("{""subtitles"":[{""url"":""https://s/1.srt"",""lang"":""spa""},{""url"":""https://t/9.srt"",""lang"":""eng""}]}"))
    merged = []
    for each t in tracks
        merged.Push(t)
    end for
    for each t in other
        merged.Push(t)
    end for
    g = SubtitlesFilter(merged, ["spa", "eng"])
    Eq("varios addons: sin repetidas", [g[0].url, g[1].url, g[2].url, g[3].url], ["https://s/1.srt", "https://s/3.srt", "https://s/2.srt", "https://t/9.srt"])
    Eq("addon sin subtitulos aporta nada", SubtitlesParse({ subtitles: "x" }).Count(), 0)
    Eq("addon con respuesta rara", SubtitlesParse(invalid).Count(), 0)
end sub

sub TestSettings()
    s = SettingsNormalize({ uiLang: "xx", maxQuality: "720p", prefLangs: [] })
    Eq("idioma invalido vuelve a es", s.uiLang, "es")
    Eq("idioma pt se conserva", SettingsNormalize({ uiLang: "pt" }).uiLang, "pt")
    Eq("tmdb pt-BR", TmdbLanguage("pt"), "pt-BR")
    Eq("tmdb en-US", TmdbLanguage("en"), "en-US")
    Eq("tmdb es-ES", TmdbLanguage("es"), "es-ES")
    TestTranslations()
    Eq("calidad", s.maxQuality, "720p")
    Eq("idiomas vacios usan los de defecto", s.prefLangs, ["es-419", "es", "en"])
    Eq("normalizar basura", SettingsNormalize("basura").uiLang, "es")
    Eq("catalogo cinemeta sin clave", SettingsCatalogProvider(SettingsDefaults()), "cinemeta")
    t = SettingsDefaults()
    t.tmdbKey = "abc"
    Eq("catalogo tmdb con clave (auto)", SettingsCatalogProvider(t), "tmdb")
    t.catalog = "cinemeta"
    Eq("cinemeta forzado", SettingsCatalogProvider(t), "cinemeta")

    d = SettingsDefaults()
    Eq("sin addons de fuentes por defecto", d.streamAddons.Count(), 0)
    Eq("subtitulos: addon por defecto", d.subAddons, ["https://opensubtitles-v3.strem.io"])
    old = SettingsNormalize({ uiLang: "en", subLangs: ["spa"] })
    Eq("ajustes viejos (sin listas de addons): fuentes vacias", old.streamAddons.Count(), 0)
    Eq("ajustes viejos: addon de subtitulos por defecto", old.subAddons, ["https://opensubtitles-v3.strem.io"])
    Eq("ajustes viejos conservan idioma de subtitulos", old.subLangs, ["spa"])
    n = SettingsNormalize({ streamAddons: ["https://a.example/manifest.json", "basura", "https://a.example"], subAddons: [] })
    Eq("lista de fuentes normalizada", n.streamAddons, ["https://a.example"])
    Eq("lista de subtitulos vacia se respeta", n.subAddons.Count(), 0)
    ' Los campos desconocidos (p. ej. de un plugin o de una versión anterior) sobreviven.
    k = SettingsNormalize({ campoRaro: "valor", otro: 5 })
    Eq("campo desconocido se conserva", k.campoRaro, "valor")
    Eq("campo desconocido numerico", k.otro, 5)
    Eq("efectivos: los del usuario", AddonsEffective(n).Count() >= 1, true)
    Eq("efectivos: sin repetir", AddonsEffective({ streamAddons: ["https://a.example", "https://a.example"], prefLangs: ["en"] })[0], "https://a.example")
end sub

sub TestMovieYears()
    Eq("año: nombre con 1968", StreamParseYear("Night.Of.The.Living.Dead.1968.1080p.BluRay.x264"), 1968)
    Eq("año: último de varios", StreamParseYear("Blade.Runner.2049.2017.2160p.UHD"), 2017)
    Eq("año: entre paréntesis, resolución 1920x1080 no cuenta", StreamParseYear("1917 (2019) 1920x1080 WEB-DL"), 2019)
    Eq("año: sin año", StreamParseYear("La noche de los muertos vivientes [Bluray 720p]") = invalid, true)
    Eq("año: solo 2160p no es año", StreamParseYear("Movie.2160p.WEB") = invalid, true)
    Eq("año: solo la primera línea", StreamParseYear("Movie.1990.1080p" + Chr(10) + "Otra.2001.mkv"), 1990)
    Eq("año: 5 dígitos no es año", StreamParseYear("Movie.20190.mkv") = invalid, true)
    Eq("año: pegado a x no es año", StreamParseYear("Movie.x1968.mkv") = invalid, true)

    c1968 = { fileName: "Night.of.the.Living.Dead.1968.1080p.BluRay.mkv", title: "" }
    c2026 = { fileName: "Night.of.the.Living.Dead.2026.1080p.CAMRip.LAT.DUB.mp4", title: "" }
    c1969 = { fileName: "Night.of.the.Living.Dead.1969.720p.mp4", title: "" }
    cNoYear = { fileName: "", title: "La noche de los muertos vivientes [Bluray 720p]" + Chr(10) + "3" }
    cTitleYear = { fileName: "", title: "Night.of.the.Living.Dead.2026.CAM" + Chr(10) + "x" }
    kept = StreamsDropOtherYears([c1968, c2026, c1969, cNoYear, cTitleYear], 1968)
    Eq("filtra por año: descarta 2026 y 2026 por título, conserva 1968/1969/sin año", kept.Count(), 3)
    Eq("filtra por año: orden conservado", [kept[0].fileName, kept[1].fileName], [c1968.fileName, c1969.fileName])
    Eq("filtra por año: sin año leído se conserva", kept[2].title, cNoYear.title)
end sub

' Pruebas del Plugins.brs neutro del repo público (solo se corren cuando no hay plugin).
sub RunStubTests()
    s = SettingsDefaults()
    Eq("stub: sin addons extra", PluginStreamAddons(s), [])
    Eq("stub: sin addons efectivos", AddonsEffective(s).Count(), 0)
    Eq("stub: sin filas extra", PluginSettingsItems(s), [])
    Eq("stub: sin advertencia", PluginSettingsWarning(s), invalid)
    Eq("stub: sin aviso de fuentes", PluginSourcesNotice(s), invalid)
    Eq("stub: sin textos extra", PluginStrings().Count(), 0)
    Eq("stub: el candidato no cambia", PluginStreamEnrich({ priority: 0 }, {}, s).priority, 0)
    r = PluginHandleSetting(s, "x")
    Eq("stub: nada que preguntar", r.ask, invalid)
    Eq("stub: teclado no cambia nada", PluginApplyKeyboard(s, "x", "texto").uiLang, "es")
    s.streamAddons = ["https://a.example"]
    Eq("stub: addon del usuario es el unico", AddonsEffective(s), ["https://a.example"])
end sub

' Idioma de la interfaz: es por defecto, en y pt eligen su columna, y si falta el portugués se usa el español.
sub TestTranslations()
    old = m.global
    m.global = { lang: "es" }
    Eq("tx es", Tx("btn_back"), "Volver")
    m.global = { lang: "en" }
    Eq("tx en", Tx("btn_back"), "Back")
    m.global = { lang: "pt" }
    Eq("tx pt", Tx("btn_back"), "Voltar")
    Eq("tx pt con argumento", Tx("home_left", 5), "Faltam 5 min")
    Eq("tx clave desconocida", Tx("no_existe_xyz"), "no_existe_xyz")
    table = StringsTable()
    table["zz_solo_es_en"] = ["Hola", "Hello"]
    Eq("tx pt sin traduccion usa es", Tx("zz_solo_es_en"), "Hola")
    m.global = { lang: "en" }
    Eq("tx en con par es/en", Tx("zz_solo_es_en"), "Hello")
    m.global = { lang: "xx" }
    Eq("tx idioma raro usa es", Tx("btn_back"), "Volver")
    table.Delete("zz_solo_es_en")
    m.global = old
end sub
