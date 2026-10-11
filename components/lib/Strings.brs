' Traducciones. Español por defecto; inglés y portugués (Brasil) como otros idiomas. El idioma activo vive en m.global.lang
' ("es" | "en" | "pt"),
' que se cambia desde Ajustes. Se usa una tabla propia (y no las carpetas locale/ de Roku) para poder cambiar el
' idioma dentro de la app sin depender del idioma del equipo.

' Devuelve la cadena traducida; %1, %2, %3 se sustituyen por los argumentos. Si falta la clave devuelve la clave.
function Tx(key as string, a1 = invalid as dynamic, a2 = invalid as dynamic, a3 = invalid as dynamic) as string
    table = StringsTable()
    lang = CurrentLang()
    if not table.DoesExist(key) then return key
    pair = table[key]
    text = pair[0]
    if lang = "en" and pair.Count() > 1 then text = pair[1]
    if lang = "pt" and pair.Count() > 2 then text = pair[2]
    return FormatArgs(text, a1, a2, a3)
end function

' Idioma activo ("es" por defecto).
function CurrentLang() as string
    g = m.global
    if g <> invalid then
        if g.lang <> invalid then
            if g.lang = "en" or g.lang = "pt" then return g.lang
        end if
    end if
    return "es"
end function

' Tabla clave -> [español, inglés, portugués]. Se construye una vez por ámbito (componente o tarea).
function StringsTable() as object
    if m.stringsTable <> invalid then return m.stringsTable
    t = {}
    ' --- general ---
    t["loading"] = ["Cargando...", "Loading...", "Carregando..."]
    t["btn_back"] = ["Volver", "Back", "Voltar"]
    t["btn_close"] = ["Cerrar", "Close", "Fechar"]
    t["btn_cancel"] = ["Cancelar", "Cancel", "Cancelar"]
    t["btn_save"] = ["Guardar", "Save", "Salvar"]
    t["btn_retry"] = ["Reintentar", "Retry", "Tentar novamente"]
    t["type_movie"] = ["Película", "Movie", "Filme"]
    t["type_series"] = ["Serie", "Series", "Série"]
    ' --- menú ---
    t["nav_home"] = ["Inicio", "Home", "Início"]
    t["nav_search"] = ["Buscar", "Search", "Buscar"]
    t["nav_mylist"] = ["Mi lista", "My list", "Minha lista"]
    t["nav_settings"] = ["Ajustes", "Settings", "Ajustes"]
    ' --- inicio ---
    t["home_continue"] = ["Continuar viendo", "Continue watching", "Continuar assistindo"]
    t["home_popular_movies"] = ["Películas populares", "Popular movies", "Filmes populares"]
    t["home_popular_series"] = ["Series populares", "Popular series", "Séries populares"]
    t["home_trending_movies"] = ["Películas en tendencia", "Trending movies", "Filmes em alta"]
    t["home_trending_series"] = ["Series en tendencia", "Trending series", "Séries em alta"]
    t["home_top_movies"] = ["Películas mejor valoradas", "Top rated movies", "Filmes mais bem avaliados"]
    t["home_top_series"] = ["Series mejor valoradas", "Top rated series", "Séries mais bem avaliadas"]
    t["home_s_e"] = ["T%1 E%2", "S%1 E%2", "T%1 E%2"]
    t["home_left"] = ["Quedan %1 min", "%1 min left", "Faltam %1 min"]
    t["err_catalog"] = ["No se pudo cargar el catálogo.", "Could not load the catalog.", "Não foi possível carregar o catálogo."]
    ' --- búsqueda ---
    t["search_title"] = ["Buscar", "Search", "Buscar"]
    t["search_prompt"] = ["Escribe el nombre de una película o serie.", "Type the name of a movie or series.", "Digite o nome de um filme ou série."]
    t["search_hint"] = ["Las búsquedas empiezan solas al dejar de escribir. Derecha para ir a los resultados.", "Searches start by themselves when you stop typing. Press right to reach the results.", "As buscas começam sozinhas quando você para de digitar. Pressione direita para ir aos resultados."]
    t["search_empty"] = ["Sin resultados para ""%1"".", "No results for ""%1"".", "Sem resultados para ""%1""."]
    t["err_search"] = ["No se pudo buscar.", "Search failed.", "Não foi possível buscar."]
    ' --- mi lista ---
    t["mylist_empty"] = ["Tu lista está vacía. Añade títulos desde su ficha.", "Your list is empty. Add titles from their page.", "Sua lista está vazia. Adicione títulos a partir dos detalhes."]
    t["mylist_hint"] = ["Pulsa * para quitar el título seleccionado.", "Press * to remove the selected title.", "Pressione * para remover o título selecionado."]
    ' --- ficha ---
    t["btn_play"] = ["Reproducir", "Play", "Reproduzir"]
    t["btn_continue"] = ["Continuar", "Resume", "Continuar"]
    t["btn_continue_ep"] = ["Continuar T%1 E%2", "Resume S%1 E%2", "Continuar T%1 E%2"]
    t["btn_addlist"] = ["+ Mi lista", "+ My list", "+ Minha lista"]
    t["btn_inlist"] = ["En mi lista", "In my list", "Na minha lista"]
    t["det_cast"] = ["Reparto", "Cast", "Elenco"]
    t["det_season"] = ["Temporada %1", "Season %1", "Temporada %1"]
    t["det_specials"] = ["Especiales", "Specials", "Especiais"]
    t["det_episode"] = ["Episodio %1", "Episode %1", "Episódio %1"]
    t["det_watching"] = ["En curso", "In progress", "Em andamento"]
    t["det_noepisodes"] = ["No hay episodios disponibles.", "No episodes available.", "Não há episódios disponíveis."]
    t["err_detail"] = ["No se pudo cargar la ficha.", "Could not load the details.", "Não foi possível carregar os detalhes."]
    t["err_noimdb_title"] = ["Sin identificador", "No identifier", "Sem identificador"]
    t["err_noimdb"] = ["Este título no tiene identificador de IMDb, así que no se pueden buscar fuentes.", "This title has no IMDb id, so sources cannot be searched.", "Este título não tem identificador do IMDb, então não é possível buscar fontes."]
    ' --- errores de red ---
    t["err_network"] = ["Sin conexión o el servidor no responde.", "No connection or the server is not responding.", "Sem conexão ou o servidor não responde."]
    t["err_auth"] = ["Clave rechazada por el servicio.", "Key rejected by the service.", "Chave rejeitada pelo serviço."]
    t["err_notfound"] = ["No se encontró el contenido.", "Content not found.", "Conteúdo não encontrado."]
    t["err_server"] = ["Error del servidor (%1).", "Server error (%1).", "Erro do servidor (%1)."]
    ' --- selector de fuentes ---
    t["src_choose"] = ["Elige una fuente", "Choose a source", "Escolha uma fonte"]
    t["src_playbest"] = ["Reproducir el mejor", "Play the best", "Reproduzir o melhor"]
    t["src_searching"] = ["Buscando fuentes...", "Looking for sources...", "Procurando fontes..."]
    t["src_empty"] = ["No se encontraron fuentes para este título.", "No sources were found for this title.", "Nenhuma fonte foi encontrada para este título."]
    t["src_nolinks"] = ["Se encontraron fuentes, pero ninguna se puede reproducir en Roku.", "Sources were found, but none can be played on Roku.", "Foram encontradas fontes, mas nenhuma pode ser reproduzida no Roku."]
    t["src_error"] = ["No se pudieron cargar las fuentes.", "Could not load the sources.", "Não foi possível carregar as fontes."]
    t["src_hint"] = ["Arriba: las mejores primero.", "Best ones first.", "As melhores primeiro."]
    t["src_noaddons"] = ["Agrega un addon de fuentes en Ajustes.", "Add a sources addon in Settings.", "Adicione um addon de fontes em Ajustes."]
    t["src_opensettings"] = ["Abrir Ajustes", "Open Settings", "Abrir Ajustes"]
    t["flt_all"] = ["Todos", "All", "Todos"]
    t["flt_es"] = ["Castellano", "Castilian", "Castelhano"]
    t["flt_latino"] = ["Latino", "Latin American", "Latino"]
    t["flt_en"] = ["Inglés", "English", "Inglês"]
    t["flt_none"] = ["Ninguna fuente coincide con el idioma elegido", "No source matches the chosen language", "Nenhuma fonte corresponde ao idioma escolhido"]
    t["src_origin"] = ["Origen: %1", "Source: %1", "Origem: %1"]
    t["tag_remux"] = ["Blu-ray original", "Original Blu-ray", "Blu-ray original"]
    t["tag_bluray"] = ["Blu-ray", "Blu-ray", "Blu-ray"]
    t["tag_web"] = ["Web", "Web", "Web"]
    t["tag_tv"] = ["TV", "TV", "TV"]
    t["tag_dvd"] = ["DVD", "DVD", "DVD"]
    t["tag_cam"] = ["Grabada en cine", "Recorded in theater", "Gravada no cinema"]
    t["tag_audio"] = ["Audio %1", "Audio %1", "Áudio %1"]
    t["lang_es"] = ["Castellano", "Castilian Spanish", "Castelhano"]
    t["lang_latino"] = ["Latino", "Latin American Spanish", "Espanhol latino"]
    t["lang_en"] = ["Inglés", "English", "Inglês"]
    t["lang_pt"] = ["Portugués", "Portuguese", "Português"]
    t["lang_fr"] = ["Francés", "French", "Francês"]
    t["lang_it"] = ["Italiano", "Italian", "Italiano"]
    t["lang_de"] = ["Alemán", "German", "Alemão"]
    t["lang_multi"] = ["Varios idiomas", "Several languages", "Vários idiomas"]
    ' --- reproductor ---
    t["player_loading"] = ["Preparando la reproducción...", "Getting ready to play...", "Preparando a reprodução..."]
    t["player_trying"] = ["Esa fuente no respondió. Probando otra...", "That source did not respond. Trying another...", "Essa fonte não respondeu. Tentando outra..."]
    t["player_failed_title"] = ["No se pudo reproducir", "Could not play", "Não foi possível reproduzir"]
    t["player_failed"] = ["Ninguna de las fuentes respondió. Prueba con otro título o con otro addon.", "None of the sources responded. Try another title or another addon.", "Nenhuma das fontes respondeu. Tente outro título ou outro addon."]
    ' --- ajustes ---
    t["set_hint"] = ["OK para cambiar; con * quitas un addon. Para pegar una URL usa el teclado de la app móvil de Roku.", "Press OK to change; press * to remove an addon. To paste a URL, use the keyboard in the Roku mobile app.", "OK para alterar; com * você remove um addon. Para colar uma URL, use o teclado do app móvel do Roku."]
    t["set_noaddons_warning"] = ["Sin un addon de fuentes no hay reproducción. Agrega uno en la lista de abajo.", "Nothing can be played without a sources addon. Add one in the list below.", "Sem um addon de fontes não há reprodução. Adicione um na lista abaixo."]
    t["set_uilang"] = ["Idioma de la app", "App language", "Idioma do app"]
    t["set_catalog"] = ["Catálogo", "Catalog", "Catálogo"]
    t["set_catalog_d"] = ["Automático usa TMDB si hay clave; si no, Cinemeta.", "Automatic uses TMDB when a key is set; otherwise Cinemeta.", "Automático usa o TMDB se houver chave; senão, o Cinemeta."]
    t["set_auto"] = ["Automático", "Automatic", "Automático"]
    t["set_tmdbkey"] = ["Clave de TMDB (opcional)", "TMDB key (optional)", "Chave do TMDB (opcional)"]
    t["set_tmdbkey_d"] = ["Datos en tu idioma y más filas. Sin clave se usa Cinemeta.", "Data in your language and more rows. Without a key Cinemeta is used.", "Dados no seu idioma e mais linhas. Sem chave, usa-se o Cinemeta."]
    t["set_tmdbkey_msg"] = ["Clave v3 o token v4 de themoviedb.org.", "v3 key or v4 token from themoviedb.org.", "Chave v3 ou token v4 de themoviedb.org."]
    t["set_langs"] = ["Idiomas preferidos", "Preferred languages", "Idiomas preferidos"]
    t["set_langs_d"] = ["Solo ordenan las fuentes, no ocultan ninguna.", "They only sort the sources, none is hidden.", "Só ordenam as fontes, nenhuma é ocultada."]
    t["set_quality"] = ["Calidad máxima", "Max quality", "Qualidade máxima"]
    t["set_quality_d"] = ["Las que la superan quedan al final de la lista.", "Those above it go to the end of the list.", "As que a excedem ficam no fim da lista."]
    t["set_noquality"] = ["Sin tope", "No limit", "Sem limite"]
    t["set_subs"] = ["Subtítulos", "Subtitles", "Legendas"]
    t["set_subs_d"] = ["Idiomas que se buscan en tus addons de subtítulos.", "Languages looked up in your subtitle addons.", "Idiomas buscados nos seus addons de legendas."]
    t["set_nosubs"] = ["Sin subtítulos", "No subtitles", "Sem legendas"]
    t["set_srcaddon"] = ["Addon de fuentes", "Sources addon", "Addon de fontes"]
    t["set_srcaddon_d"] = ["Pulsa * para quitarlo.", "Press * to remove it.", "Pressione * para removê-lo."]
    t["set_addsrc"] = ["Agregar addon de fuentes", "Add sources addon", "Adicionar addon de fontes"]
    t["set_addsrc_d"] = ["URL del addon (la del manifest sirve).", "Addon URL (the manifest URL works).", "URL do addon (a do manifest serve)."]
    t["set_subaddon"] = ["Addon de subtítulos", "Subtitles addon", "Addon de legendas"]
    t["set_addsub"] = ["Agregar addon de subtítulos", "Add subtitles addon", "Adicionar addon de legendas"]
    t["set_addon_msg"] = ["Escribe o pega la URL del addon. Puedes pegarla desde el teclado de la app móvil de Roku.", "Type or paste the addon URL. You can paste it from the keyboard in the Roku mobile app.", "Digite ou cole a URL do addon. Você pode colá-la pelo teclado do app móvel do Roku."]
    t["set_addon_bad"] = ["Esa no es una URL válida (debe empezar con http:// o https://).", "That is not a valid URL (it must start with http:// or https://).", "Essa não é uma URL válida (deve começar com http:// ou https://)."]
    t["set_addon_info"] = ["Para quitarlo, enfócalo y pulsa * en el mando.", "To remove it, focus it and press * on the remote.", "Para removê-lo, selecione-o e pressione * no controle."]
    t["set_clear"] = ["Borrar ""Continuar viendo""", "Clear ""Continue watching""", "Apagar ""Continuar assistindo"""]
    t["set_clear_d"] = ["Olvida lo que estabas viendo.", "Forget what you were watching.", "Esquece o que você estava assistindo."]
    t["set_cleared"] = ["Listo: se borró el historial.", "Done: history cleared.", "Pronto: o histórico foi apagado."]
    t["set_about"] = ["Acerca de", "About", "Sobre"]
    t["set_about_d"] = ["Versión, TMDB y aviso legal.", "Version, TMDB and legal notice.", "Versão, TMDB e aviso legal."]
    t["set_notset"] = ["Sin configurar", "Not set", "Não configurado"]
    t["about_text"] = ["Parche Roku: centro multimedia para Roku que reproduce contenido de los addons que tú agregas (compatible con el protocolo de addons de Stremio). Catálogo de Cinemeta o TMDB.", "Parche Roku: a media center for Roku that plays content from the addons you add (compatible with the Stremio addon protocol). Catalog from Cinemeta or TMDB.", "Parche Roku: central de mídia para Roku que reproduz conteúdo dos addons que você adiciona (compatível com o protocolo de addons do Stremio). Catálogo do Cinemeta ou TMDB."]
    t["tmdb_attr"] = ["Este producto usa la API de TMDB, pero no está avalado ni certificado por TMDB.", "This product uses the TMDB API but is not endorsed or certified by TMDB.", "Este produto usa a API do TMDB, mas não é endossado nem certificado pelo TMDB."]
    t["legal"] = ["Este canal no incluye ni aloja contenido: reproduce lo que ofrecen los addons que tú agregas. Eres responsable de tener derecho a acceder a ese contenido y de cumplir las leyes y los términos de los servicios que uses.", "This channel neither includes nor hosts any content: it plays what the addons you add provide. You are responsible for having the right to access that content and for complying with the laws and the terms of the services you use.", "Este canal não inclui nem hospeda conteúdo: reproduz o que os addons que você adiciona oferecem. Você é responsável por ter o direito de acessar esse conteúdo e por cumprir as leis e os termos dos serviços que usar."]
    ' Un plugin puede agregar traducciones o reemplazar las de arriba.
    extra = PluginStrings()
    for each k in extra
        t[k] = extra[k]
    end for
    m.stringsTable = t
    return t
end function
