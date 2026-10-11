' Selector de fuentes. Pide a los addons configurados las fuentes del título o episodio y las muestra ya ordenadas.
' Sin ningún addon explica cómo agregar uno (o muestra el aviso del plugin) y ofrece abrir Ajustes.

sub init()
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.best = m.top.findNode("best")
    m.list = m.top.findNode("list")
    m.status = m.top.findNode("status")
    m.settingsBtn = m.top.findNode("settingsBtn")
    m.hint = m.top.findNode("hint")
    m.chips = m.top.findNode("chips")
    m.emptyMsg = m.top.findNode("emptyMsg")

    m.best.items = [Tx("src_playbest")]
    m.best.observeField("selected", "onBest")
    m.chipCodes = ["", "es-419", "es", "en"]
    m.chips.items = [Tx("flt_all"), Tx("flt_latino"), Tx("flt_es"), Tx("flt_en")]
    m.chips.activeIndex = 0
    m.chips.observeField("selected", "onChip")
    m.emptyMsg.text = Tx("flt_none")
    m.settingsBtn.items = [Tx("src_opensettings")]
    m.settingsBtn.observeField("selected", "onOpenSettings")
    m.list.observeField("itemSelected", "onPick")
    m.hint.text = Tx("src_hint")
    m.sources = []
    m.allSources = []
    m.pendingId = -1
    m.backOnly = false
    m.req = invalid
end sub

sub onRequest()
    m.req = m.top.request
    if m.req = invalid then return
    item = m.req.item
    m.title.text = NzStr(item.title)
    sub_ = Tx("src_choose")
    if ToInt(m.req.season, -1) >= 0 then
        sub_ = Tx("home_s_e", m.req.season, m.req.episode)
        if NzStr(m.req.episodeTitle) <> "" then sub_ = sub_ + " " + Chr(183) + " " + m.req.episodeTitle
    end if
    m.subtitle.text = sub_

    s = SettingsLoad()
    if AddonsEffective(s).Count() = 0 then
        notice = PluginSourcesNotice(s)
        if IsStr(notice) then
            showMessage(notice, true)
        else
            showMessage(Tx("src_noaddons"), true)
        end if
        return
    end if
    showMessage(Tx("src_searching"), false)
    m.pendingId = ApiRequest({
        kind: "streams"
        mediaType: NzStr(item.type, "movie")
        imdbId: item.id
        year: ToInt(item.year)
        season: ToInt(m.req.season, -1)
        episode: ToInt(m.req.episode, -1)
        settings: s
    }, "onStreams")
end sub

' Muestra un mensaje centrado; withSettings añade el botón que abre los ajustes.
sub showMessage(text as string, withSettings as boolean)
    m.status.text = text
    m.status.visible = true
    m.list.visible = false
    m.best.visible = false
    m.chips.visible = false
    m.emptyMsg.visible = false
    m.settingsBtn.visible = withSettings
    if withSettings then m.settingsBtn.setFocus(true)
end sub

sub onStreams(event as object)
    res = ApiTake(event)
    if res.reqId <> m.pendingId then return
    if not res.ok then
        showMessage(Tx("src_error") + chr(10) + res.error, false)
        m.settingsBtn.items = [Tx("btn_back")]
        m.settingsBtn.visible = true
        m.settingsBtn.setFocus(true)
        m.backOnly = true
        return
    end if
    m.allSources = res.data.sources
    m.sources = m.allSources
    if m.allSources.Count() = 0 then
        text = Tx("src_empty")
        if res.data.total > 0 then text = Tx("src_nolinks")
        showMessage(text, false)
        m.settingsBtn.items = [Tx("btn_back")]
        m.settingsBtn.visible = true
        m.settingsBtn.setFocus(true)
        m.backOnly = true
        return
    end if
    m.chips.index = 0
    m.chips.activeIndex = 0
    m.status.visible = false
    m.settingsBtn.visible = false
    m.best.visible = true
    m.chips.visible = true
    applyFilter()
    m.best.setFocus(true)
end sub

' Reconstruye la lista con el filtro de idioma elegido sobre las fuentes ya ordenadas.
sub applyFilter()
    code = m.chipCodes[m.chips.activeIndex]
    m.sources = StreamsFilterByLanguage(m.allSources, code)
    root = CreateObject("roSGNode", "ContentNode")
    for each c in m.sources
        d = StreamDescribe(c)
        root.appendChild(MakeRowNode(d.line1, d.line2, d.avail, d.availColor))
    end for
    m.list.content = root
    m.list.visible = m.sources.Count() > 0
    m.emptyMsg.visible = m.sources.Count() = 0
end sub

sub onChip()
    i = m.chips.selected
    if i < 0 or i >= m.chipCodes.Count() then return
    m.chips.activeIndex = i
    applyFilter()
end sub

sub onBest()
    play(0)
end sub

sub onPick()
    play(m.list.itemSelected)
end sub

sub play(index as integer)
    if m.sources.Count() = 0 then return
    m.top.action = {
        type: "play"
        item: m.req.item
        season: ToInt(m.req.season, -1)
        episode: ToInt(m.req.episode, -1)
        episodeTitle: NzStr(m.req.episodeTitle)
        sources: m.sources
        index: index
    }
end sub

sub onOpenSettings()
    if m.backOnly = true then
        m.top.action = { type: "back" }
    else
        m.top.action = { type: "settings" }
    end if
end sub

sub activate()
    if m.chips.isInFocusChain() or m.list.isInFocusChain() then
        return
    else if m.best.visible then
        m.best.setFocus(true)
    else if m.settingsBtn.visible then
        m.settingsBtn.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back" then
        m.top.action = { type: "back" }
        return true
    else if key = "down" and m.best.isInFocusChain() then
        if m.chips.visible then
            m.chips.setFocus(true)
            return true
        end if
    else if key = "down" and m.chips.isInFocusChain() then
        if m.list.visible then m.list.setFocus(true)
        return true
    else if key = "up" and m.chips.isInFocusChain() then
        m.best.setFocus(true)
        return true
    else if key = "up" and m.list.isInFocusChain() then
        if m.list.itemFocused = 0 then
            m.chips.setFocus(true)
            return true
        end if
    end if
    return false
end function
