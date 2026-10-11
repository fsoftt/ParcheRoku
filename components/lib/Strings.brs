' Traducciones. Español por defecto; inglés como segundo idioma. El idioma activo vive en m.global.lang ("es" | "en"),
' que se cambia desde Ajustes. Se usa una tabla propia (y no las carpetas locale/ de Roku) para poder cambiar el
' idioma dentro de la app sin depender del idioma del equipo.

' Devuelve la cadena traducida; %1, %2, %3 se sustituyen por los argumentos. Si falta la clave devuelve la clave.
function Tx(key as string, a1 = invalid as dynamic, a2 = invalid as dynamic, a3 = invalid as dynamic) as string
    table = StringsTable()
    lang = CurrentLang()
    if not table.DoesExist(key) then return key
    pair = table[key]
    text = pair[0]
    if lang = "en" then text = pair[1]
    return FormatArgs(text, a1, a2, a3)
end function

' Idioma activo ("es" por defecto).
function CurrentLang() as string
    g = m.global
    if g <> invalid then
        if g.lang <> invalid then
            if g.lang = "en" then return "en"
        end if
    end if
    return "es"
end function

' Tabla clave -> [español, inglés]. Se construye una vez por ámbito (componente o tarea).
function StringsTable() as object
    if m.stringsTable <> invalid then return m.stringsTable
    t = {}
    ' --- general ---
    t["loading"] = ["Cargando...", "Loading..."]
    t["btn_back"] = ["Volver", "Back"]
    t["btn_close"] = ["Cerrar", "Close"]
    t["btn_cancel"] = ["Cancelar", "Cancel"]
    t["btn_save"] = ["Guardar", "Save"]
    t["btn_retry"] = ["Reintentar", "Retry"]
    t["type_movie"] = ["Película", "Movie"]
    t["type_series"] = ["Serie", "Series"]
    ' --- menú ---
    t["nav_home"] = ["Inicio", "Home"]
    t["nav_search"] = ["Buscar", "Search"]
    t["nav_mylist"] = ["Mi lista", "My list"]
    t["nav_settings"] = ["Ajustes", "Settings"]
    ' --- inicio ---
    t["home_continue"] = ["Continuar viendo", "Continue watching"]
    t["home_popular_movies"] = ["Películas populares", "Popular movies"]
    t["home_popular_series"] = ["Series populares", "Popular series"]
    t["home_trending_movies"] = ["Películas en tendencia", "Trending movies"]
    t["home_trending_series"] = ["Series en tendencia", "Trending series"]
    t["home_top_movies"] = ["Películas mejor valoradas", "Top rated movies"]
    t["home_top_series"] = ["Series mejor valoradas", "Top rated series"]
    t["home_s_e"] = ["T%1 E%2", "S%1 E%2"]
    t["home_left"] = ["Quedan %1 min", "%1 min left"]
    t["err_catalog"] = ["No se pudo cargar el catálogo.", "Could not load the catalog."]
    ' --- búsqueda ---
    t["search_title"] = ["Buscar", "Search"]
    t["search_prompt"] = ["Escribe el nombre de una película o serie.", "Type the name of a movie or series."]
    t["search_hint"] = ["Las búsquedas empiezan solas al dejar de escribir. Derecha para ir a los resultados.", "Searches start by themselves when you stop typing. Press right to reach the results."]
    t["search_empty"] = ["Sin resultados para ""%1"".", "No results for ""%1""."]
    t["err_search"] = ["No se pudo buscar.", "Search failed."]
    ' --- mi lista ---
    t["mylist_empty"] = ["Tu lista está vacía. Añade títulos desde su ficha.", "Your list is empty. Add titles from their page."]
    t["mylist_hint"] = ["Pulsa * para quitar el título seleccionado.", "Press * to remove the selected title."]
    ' --- ficha ---
    t["btn_play"] = ["Reproducir", "Play"]
    t["btn_continue"] = ["Continuar", "Resume"]
    t["btn_continue_ep"] = ["Continuar T%1 E%2", "Resume S%1 E%2"]
    t["btn_addlist"] = ["+ Mi lista", "+ My list"]
    t["btn_inlist"] = ["En mi lista", "In my list"]
    t["det_cast"] = ["Reparto", "Cast"]
    t["det_season"] = ["Temporada %1", "Season %1"]
    t["det_specials"] = ["Especiales", "Specials"]
    t["det_episode"] = ["Episodio %1", "Episode %1"]
    t["det_watching"] = ["En curso", "In progress"]
    t["det_noepisodes"] = ["No hay episodios disponibles.", "No episodes available."]
    t["err_detail"] = ["No se pudo cargar la ficha.", "Could not load the details."]
    t["err_noimdb_title"] = ["Sin identificador", "No identifier"]
    t["err_noimdb"] = ["Este título no tiene identificador de IMDb, así que no se pueden buscar fuentes.", "This title has no IMDb id, so sources cannot be searched."]
    ' --- errores de red ---
    t["err_network"] = ["Sin conexión o el servidor no responde.", "No connection or the server is not responding."]
    t["err_auth"] = ["Clave rechazada por el servicio.", "Key rejected by the service."]
    t["err_notfound"] = ["No se encontró el contenido.", "Content not found."]
    t["err_server"] = ["Error del servidor (%1).", "Server error (%1)."]
    ' --- selector de fuentes ---
    t["src_choose"] = ["Elige una fuente", "Choose a source"]
    t["src_playbest"] = ["Reproducir el mejor", "Play the best"]
    t["src_searching"] = ["Buscando fuentes...", "Looking for sources..."]
    t["src_empty"] = ["No se encontraron fuentes para este título.", "No sources were found for this title."]
    t["src_nolinks"] = ["Se encontraron fuentes, pero ninguna se puede reproducir en Roku.", "Sources were found, but none can be played on Roku."]
    t["src_error"] = ["No se pudieron cargar las fuentes.", "Could not load the sources."]
    t["src_hint"] = ["Arriba: las mejores primero.", "Best ones first."]
    t["src_noaddons"] = ["Agrega un addon de fuentes en Ajustes.", "Add a sources addon in Settings."]
    t["src_opensettings"] = ["Abrir Ajustes", "Open Settings"]
    t["flt_all"] = ["Todos", "All"]
    t["flt_es"] = ["Castellano", "Castilian"]
    t["flt_latino"] = ["Latino", "Latin American"]
    t["flt_en"] = ["Inglés", "English"]
    t["flt_none"] = ["Ninguna fuente coincide con el idioma elegido", "No source matches the chosen language"]
    t["src_origin"] = ["Origen: %1", "Source: %1"]
    t["tag_remux"] = ["Blu-ray original", "Original Blu-ray"]
    t["tag_bluray"] = ["Blu-ray", "Blu-ray"]
    t["tag_web"] = ["Web", "Web"]
    t["tag_tv"] = ["TV", "TV"]
    t["tag_dvd"] = ["DVD", "DVD"]
    t["tag_cam"] = ["Grabada en cine", "Recorded in theater"]
    t["tag_audio"] = ["Audio %1", "Audio %1"]
    t["lang_es"] = ["Castellano", "Castilian Spanish"]
    t["lang_latino"] = ["Latino", "Latin American Spanish"]
    t["lang_en"] = ["Inglés", "English"]
    t["lang_pt"] = ["Portugués", "Portuguese"]
    t["lang_fr"] = ["Francés", "French"]
    t["lang_it"] = ["Italiano", "Italian"]
    t["lang_de"] = ["Alemán", "German"]
    t["lang_multi"] = ["Varios idiomas", "Several languages"]
    ' --- reproductor ---
    t["player_loading"] = ["Preparando la reproducción...", "Getting ready to play..."]
    t["player_trying"] = ["Esa fuente no respondió. Probando otra...", "That source did not respond. Trying another..."]
    t["player_failed_title"] = ["No se pudo reproducir", "Could not play"]
    t["player_failed"] = ["Ninguna de las fuentes respondió. Prueba con otro título o con otro addon.", "None of the sources responded. Try another title or another addon."]
    ' --- ajustes ---
    t["set_hint"] = ["OK para cambiar; con * quitas un addon. Para pegar una URL usa el teclado de la app móvil de Roku.", "Press OK to change; press * to remove an addon. To paste a URL, use the keyboard in the Roku mobile app."]
    t["set_noaddons_warning"] = ["Sin un addon de fuentes no hay reproducción. Agrega uno en la lista de abajo.", "Nothing can be played without a sources addon. Add one in the list below."]
    t["set_uilang"] = ["Idioma de la app", "App language"]
    t["set_catalog"] = ["Catálogo", "Catalog"]
    t["set_catalog_d"] = ["Automático usa TMDB si hay clave; si no, Cinemeta.", "Automatic uses TMDB when a key is set; otherwise Cinemeta."]
    t["set_auto"] = ["Automático", "Automatic"]
    t["set_tmdbkey"] = ["Clave de TMDB (opcional)", "TMDB key (optional)"]
    t["set_tmdbkey_d"] = ["Datos en tu idioma y más filas. Sin clave se usa Cinemeta.", "Data in your language and more rows. Without a key Cinemeta is used."]
    t["set_tmdbkey_msg"] = ["Clave v3 o token v4 de themoviedb.org.", "v3 key or v4 token from themoviedb.org."]
    t["set_langs"] = ["Idiomas preferidos", "Preferred languages"]
    t["set_langs_d"] = ["Solo ordenan las fuentes, no ocultan ninguna.", "They only sort the sources, none is hidden."]
    t["set_quality"] = ["Calidad máxima", "Max quality"]
    t["set_quality_d"] = ["Las que la superan quedan al final de la lista.", "Those above it go to the end of the list."]
    t["set_noquality"] = ["Sin tope", "No limit"]
    t["set_subs"] = ["Subtítulos", "Subtitles"]
    t["set_subs_d"] = ["Idiomas que se buscan en tus addons de subtítulos.", "Languages looked up in your subtitle addons."]
    t["set_nosubs"] = ["Sin subtítulos", "No subtitles"]
    t["set_srcaddon"] = ["Addon de fuentes", "Sources addon"]
    t["set_srcaddon_d"] = ["Pulsa * para quitarlo.", "Press * to remove it."]
    t["set_addsrc"] = ["Agregar addon de fuentes", "Add sources addon"]
    t["set_addsrc_d"] = ["URL del addon (la del manifest sirve).", "Addon URL (the manifest URL works)."]
    t["set_subaddon"] = ["Addon de subtítulos", "Subtitles addon"]
    t["set_addsub"] = ["Agregar addon de subtítulos", "Add subtitles addon"]
    t["set_addon_msg"] = ["Escribe o pega la URL del addon. Puedes pegarla desde el teclado de la app móvil de Roku.", "Type or paste the addon URL. You can paste it from the keyboard in the Roku mobile app."]
    t["set_addon_bad"] = ["Esa no es una URL válida (debe empezar con http:// o https://).", "That is not a valid URL (it must start with http:// or https://)."]
    t["set_addon_info"] = ["Para quitarlo, enfócalo y pulsa * en el mando.", "To remove it, focus it and press * on the remote."]
    t["set_clear"] = ["Borrar ""Continuar viendo""", "Clear ""Continue watching"""]
    t["set_clear_d"] = ["Olvida lo que estabas viendo.", "Forget what you were watching."]
    t["set_cleared"] = ["Listo: se borró el historial.", "Done: history cleared."]
    t["set_about"] = ["Acerca de", "About"]
    t["set_about_d"] = ["Versión, TMDB y aviso legal.", "Version, TMDB and legal notice."]
    t["set_notset"] = ["Sin configurar", "Not set"]
    t["about_text"] = ["Parche Roku: centro multimedia para Roku que reproduce contenido de los addons que tú agregas (compatible con el protocolo de addons de Stremio). Catálogo de Cinemeta o TMDB.", "Parche Roku: a media center for Roku that plays content from the addons you add (compatible with the Stremio addon protocol). Catalog from Cinemeta or TMDB."]
    t["tmdb_attr"] = ["Este producto usa la API de TMDB, pero no está avalado ni certificado por TMDB.", "This product uses the TMDB API but is not endorsed or certified by TMDB."]
    t["legal"] = ["Este canal no incluye ni aloja contenido: reproduce lo que ofrecen los addons que tú agregas. Eres responsable de tener derecho a acceder a ese contenido y de cumplir las leyes y los términos de los servicios que uses.", "This channel neither includes nor hosts any content: it plays what the addons you add provide. You are responsible for having the right to access that content and for complying with the laws and the terms of the services you use."]
    ' Un plugin puede agregar traducciones o reemplazar las de arriba.
    extra = PluginStrings()
    for each k in extra
        t[k] = extra[k]
    end for
    m.stringsTable = t
    return t
end function
