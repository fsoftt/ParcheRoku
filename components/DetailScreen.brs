' Ficha. Muestra al instante lo que ya se sabe del título y completa la ficha desde el catálogo.

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
    m.desc = m.top.findNode("desc")
    m.cast = m.top.findNode("cast")
    m.actions = m.top.findNode("actions")
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.status = m.top.findNode("status")

    m.actions.observeField("selected", "onAction")
    m.seasons.observeField("itemFocused", "onSeasonFocused")
    m.seasons.observeField("itemSelected", "onSeasonSelected")
    m.episodes.observeField("itemSelected", "onEpisodeSelected")

    m.detail = invalid
    m.pendingId = -1
    m.seasonReq = -1
    m.seasonData = []
    m.shownSeason = -1
    m.playMode = "play"
    m.watchEntry = invalid
end sub

sub onItem()
    item = m.top.item
    if item = invalid then return
    m.detail = item
    showBasics(item)
    m.status.text = Tx("loading")
    m.actions.visible = false
    m.pendingId = ApiRequest({ kind: "detail", item: item }, "onDetail")
end sub

sub showBasics(item as object)
    img = NzStr(item.backdrop)
    if img = "" then img = NzStr(item.poster)
    m.backdrop.uri = img
    m.poster.uri = NzStr(item.poster)
    m.title.text = NzStr(item.title)
    m.meta.text = MetaLine(item)
    m.desc.text = NzStr(item.description)
end sub

sub onDetail(event as object)
    res = ApiTake(event)
    if res.reqId <> m.pendingId then return
    if not res.ok then
        m.status.text = Tx("err_detail") + chr(10) + res.error
        m.actions.items = [Tx("btn_back")]
        m.playMode = "back"
        m.actions.visible = true
        m.actions.setFocus(true)
        return
    end if
    m.detail = res.data
    m.status.text = ""
    showBasics(m.detail)
    if type(m.detail.cast) = "roArray" and m.detail.cast.Count() > 0 then
        m.cast.text = Tx("det_cast") + ": " + ArrayJoin(m.detail.cast, ", ")
    end if
    m.seasonData = m.detail.seasons
    refreshActions()
    m.actions.visible = true
    if m.detail.type = "series" and m.seasonData.Count() > 0 then
        buildSeasons()
    end if
    m.actions.setFocus(true)
end sub

' Etiquetas de los botones según el avance guardado y si está en Mi lista.
sub refreshActions()
    if m.detail = invalid then return
    m.watchEntry = CwFindTitle(WatchLoad(), m.detail)
    playText = Tx("btn_play")
    if m.watchEntry <> invalid then
        if ToInt(m.watchEntry.season, -1) >= 0 then
            playText = Tx("btn_continue_ep", m.watchEntry.season, m.watchEntry.episode)
        else
            playText = Tx("btn_continue")
        end if
    end if
    listText = Tx("btn_addlist")
    if MyListHas(m.detail) then listText = Tx("btn_inlist")
    m.actions.items = [playText, listText]
end sub

sub onAction()
    i = m.actions.selected
    if m.playMode = "back" then
        m.top.action = { type: "back" }
        return
    end if
    if i = 0 then
        play()
    else if i = 1 then
        MyListToggle(m.detail)
        refreshActions()
    end if
end sub

' Botón principal: continúa lo que se estaba viendo o empieza por el principio.
sub play()
    if m.detail = invalid then return
    if Left(NzStr(m.detail.id), 2) <> "tt" then
        OpenMessageDialog(Tx("err_noimdb_title"), [Tx("err_noimdb")], m.top)
        return
    end if
    if m.detail.type <> "series" then
        if m.watchEntry <> invalid and m.watchEntry.source <> invalid then
            m.top.action = { type: "resume", entry: m.watchEntry }
        else
            m.top.action = { type: "sources", item: m.detail, season: -1, episode: -1, episodeTitle: "" }
        end if
        return
    end if
    ' Serie
    if m.watchEntry <> invalid and ToInt(m.watchEntry.season, -1) >= 0 then
        if m.watchEntry.source <> invalid then
            m.top.action = { type: "resume", entry: m.watchEntry }
        else
            m.top.action = { type: "sources", item: m.detail, season: m.watchEntry.season, episode: m.watchEntry.episode, episodeTitle: NzStr(m.watchEntry.episodeTitle) }
        end if
        return
    end if
    first = firstEpisode()
    if first = invalid then
        m.status.text = Tx("det_noepisodes")
        return
    end if
    m.top.action = { type: "sources", item: m.detail, season: first.season, episode: first.number, episodeTitle: first.title }
end sub

' Primer episodio reproducible: el primero de la primera temporada con episodios cargados (no especiales).
function firstEpisode() as dynamic
    for each s in m.seasonData
        if s.number > 0 and type(s.episodes) = "roArray" then
            if s.episodes.Count() > 0 then return s.episodes[0]
        end if
    end for
    for each s in m.seasonData
        if type(s.episodes) = "roArray" then
            if s.episodes.Count() > 0 then return s.episodes[0]
        end if
    end for
    return invalid
end function

' ---------- temporadas y episodios ----------

sub buildSeasons()
    root = CreateObject("roSGNode", "ContentNode")
    for each s in m.seasonData
        root.appendChild(MakeRowNode(s.title))
    end for
    m.seasons.content = root
    m.seasons.visible = true
    ' Empieza en la temporada del avance guardado o en la primera que no sea de especiales.
    start = 0
    for i = 0 to m.seasonData.Count() - 1
        if m.seasonData[i].number > 0 then
            start = i
            exit for
        end if
    end for
    if m.watchEntry <> invalid and ToInt(m.watchEntry.season, -1) >= 0 then
        for i = 0 to m.seasonData.Count() - 1
            if m.seasonData[i].number = m.watchEntry.season then start = i
        end for
    end if
    m.seasons.jumpToItem = start
    showSeason(start)
end sub

sub onSeasonFocused()
    i = m.seasons.itemFocused
    if i >= 0 then showSeason(i)
end sub

sub onSeasonSelected()
    m.episodes.setFocus(true)
end sub

sub showSeason(idx as integer)
    if idx < 0 or idx = m.shownSeason or idx >= m.seasonData.Count() then return
    m.shownSeason = idx
    s = m.seasonData[idx]
    if type(s.episodes) = "roArray" then
        buildEpisodes(s)
        return
    end if
    ' TMDB: los episodios se piden al enfocar la temporada.
    m.episodes.visible = false
    m.status.text = Tx("loading")
    m.seasonReq = ApiRequest({ kind: "season", tmdbId: m.detail.tmdbId, season: s.number }, "onSeason")
end sub

sub onSeason(event as object)
    res = ApiTake(event)
    if res.reqId <> m.seasonReq then return
    m.status.text = ""
    if not res.ok then
        m.status.text = Tx("err_detail") + chr(10) + res.error
        return
    end if
    for each s in m.seasonData
        if s.number = res.data.season then s.episodes = res.data.episodes
    end for
    if m.shownSeason >= 0 and m.seasonData[m.shownSeason].number = res.data.season then
        buildEpisodes(m.seasonData[m.shownSeason])
    end if
end sub

sub buildEpisodes(season as object)
    m.status.text = ""
    root = CreateObject("roSGNode", "ContentNode")
    watch = WatchLoad()
    for each e in season.episodes
        n = CreateObject("roSGNode", "RowNode")
        n.title = e.number.ToStr() + ". " + e.title
        n.line2 = Ellipsize(NzStr(e.overview), 200)
        n.image = NzStr(e.thumbnail)
        n.data = { season: e.season, number: e.number, title: e.title }
        w = CwFind(watch, m.detail, e.season, e.number)
        if w <> invalid then n.right = Tx("det_watching")
        root.appendChild(n)
    end for
    m.episodes.content = root
    m.episodes.visible = true
    if season.episodes.Count() = 0 then m.status.text = Tx("det_noepisodes")
end sub

sub onEpisodeSelected()
    i = m.episodes.itemSelected
    root = m.episodes.content
    if root = invalid or i < 0 then return
    n = root.getChild(i)
    if n = invalid then return
    if Left(NzStr(m.detail.id), 2) <> "tt" then
        OpenMessageDialog(Tx("err_noimdb_title"), [Tx("err_noimdb")], m.top)
        return
    end if
    d = n.data
    entry = CwFind(WatchLoad(), m.detail, d.season, d.number)
    if entry <> invalid and entry.source <> invalid then
        m.top.action = { type: "resume", entry: entry }
    else
        m.top.action = { type: "sources", item: m.detail, season: d.season, episode: d.number, episodeTitle: d.title }
    end if
end sub

sub activate()
    if m.detail <> invalid and m.actions.visible then
        refreshActions()
        m.shownSeason = -1
        if m.seasons.visible then showSeason(m.seasons.itemFocused)
    end if
    if m.episodes.isInFocusChain() or m.seasons.isInFocusChain() then return
    if m.actions.visible then
        m.actions.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back" then
        m.top.action = { type: "back" }
        return true
    else if key = "down" and m.actions.isInFocusChain() then
        if m.seasons.visible then
            m.seasons.setFocus(true)
            return true
        end if
    else if key = "up" and (m.seasons.isInFocusChain() or m.episodes.isInFocusChain()) then
        if m.seasons.isInFocusChain() and m.seasons.itemFocused = 0 then
            m.actions.setFocus(true)
            return true
        else if m.episodes.isInFocusChain() and m.episodes.itemFocused = 0 then
            m.actions.setFocus(true)
            return true
        end if
    else if key = "right" and m.seasons.isInFocusChain() then
        if m.episodes.visible then
            m.episodes.setFocus(true)
            return true
        end if
    else if key = "left" and m.episodes.isInFocusChain() then
        m.seasons.setFocus(true)
        return true
    end if
    return false
end function
