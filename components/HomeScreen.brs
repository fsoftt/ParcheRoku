' Portada. Carga el catálogo en ApiTask y muestra "Continuar viendo" (del registro) como primera fila.

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.gradLeft = m.top.findNode("gradLeft")
    m.gradBottom = m.top.findNode("gradBottom")
    m.nav = m.top.findNode("nav")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroDesc = m.top.findNode("heroDesc")
    m.rows = m.top.findNode("rows")
    m.status = m.top.findNode("status")
    m.retry = m.top.findNode("retry")

    m.nav.items = [Tx("nav_home"), Tx("nav_search"), Tx("nav_mylist"), Tx("nav_settings")]
    m.nav.activeIndex = 0
    m.nav.index = 0
    m.nav.observeField("selected", "onNav")
    m.retry.items = [Tx("btn_retry")]
    m.retry.observeField("selected", "onRetry")
    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.rows.observeField("rowItemFocused", "onItemFocused")

    m.rowsData = []
    m.watch = []
    m.hasContinue = false
    m.watchSig = ""
    m.loaded = false
    m.loadedSig = ""
    m.pendingId = -1
    load()
end sub

' Firma de los ajustes que afectan al catálogo; si cambia, se vuelve a cargar.
function settingsSig() as string
    s = SettingsLoad()
    return SettingsCatalogProvider(s) + "|" + s.tmdbKey + "|" + s.uiLang
end function

sub load()
    m.loadedSig = settingsSig()
    m.rows.visible = false
    m.retry.visible = false
    m.status.visible = true
    m.status.text = Tx("loading")
    m.heroTitle.text = ""
    m.heroMeta.text = ""
    m.heroDesc.text = ""
    m.pendingId = ApiRequest({ kind: "home" }, "onHome")
end sub

sub onHome(event as object)
    res = ApiTake(event)
    if res.reqId <> m.pendingId then return
    if not res.ok then
        m.status.text = Tx("err_catalog") + chr(10) + res.error
        m.retry.visible = true
        m.retry.setFocus(true)
        return
    end if
    m.rowsData = res.data.rows
    m.loaded = true
    m.status.visible = false
    buildRows()
    m.rows.visible = true
    ' Solo se toma el foco si esta pantalla sigue visible (no si el usuario ya se fue a otra mientras cargaba).
    if m.top.visible then m.rows.setFocus(true)
end sub

' Construye el contenido de las filas: Continuar viendo (si hay) + las del catálogo.
sub buildRows()
    root = CreateObject("roSGNode", "ContentNode")
    m.watch = WatchLoad()
    m.hasContinue = m.watch.Count() > 0
    m.watchSig = watchSignature()
    if m.hasContinue then
        row = root.createChild("ContentNode")
        row.title = Tx("home_continue")
        for each e in m.watch
            row.appendChild(MakeMediaNode(e.item, CwFraction(e)))
        end for
    end if
    for each r in m.rowsData
        row = root.createChild("ContentNode")
        row.title = r.title
        for each it in r.items
            row.appendChild(MakeMediaNode(it))
        end for
    end for
    m.rows.content = root
    ' Con filas ya mostradas no se recoloca el foco; el héroe se actualiza al enfocar.
    showHero(0, 0)
end sub

function watchSignature() as string
    sig = ""
    for each e in m.watch
        sig = sig + ItemKey(e.item) + ":" + NzStr(e.positionMs) + ";"
    end for
    return sig
end function

' Muestra en el héroe el título (fila, columna).
sub showHero(rowIdx as integer, colIdx as integer)
    root = m.rows.content
    if root = invalid then return
    row = root.getChild(rowIdx)
    if row = invalid then return
    node = row.getChild(colIdx)
    if node = invalid then return
    item = node.media
    if item = invalid then return
    img = NzStr(item.backdrop)
    if img = "" then img = NzStr(item.poster)
    m.backdrop.uri = img
    m.heroTitle.text = NzStr(item.title)
    isContinue = m.hasContinue and rowIdx = 0
    if isContinue and colIdx < m.watch.Count() then
        e = m.watch[colIdx]
        meta = ""
        if ToInt(e.season, -1) >= 0 then meta = Tx("home_s_e", e.season, e.episode) + "   "
        left_ = Int((e.durationMs - e.positionMs) / 60000)
        if left_ > 0 then meta = meta + Tx("home_left", left_)
        m.heroMeta.text = meta
        m.heroDesc.text = NzStr(e.episodeTitle)
    else
        m.heroMeta.text = MetaLine(item)
        m.heroDesc.text = Ellipsize(NzStr(item.description), 260)
    end if
end sub

sub onItemFocused()
    f = m.rows.rowItemFocused
    if f <> invalid and f.Count() >= 2 then showHero(f[0], f[1])
end sub

sub onItemSelected()
    s = m.rows.rowItemSelected
    if s = invalid or s.Count() < 2 then return
    if m.hasContinue and s[0] = 0 then
        if s[1] < m.watch.Count() then m.top.action = { type: "resume", entry: m.watch[s[1]] }
        return
    end if
    node = m.rows.content.getChild(s[0]).getChild(s[1])
    if node <> invalid and node.media <> invalid then m.top.action = { type: "openDetail", item: node.media }
end sub

sub onNav()
    m.top.action = { type: "nav", index: m.nav.selected }
end sub

sub onRetry()
    load()
end sub

' Lo llama MainScene al mostrar la pantalla: recarga si cambió el catálogo y refresca "Continuar viendo".
sub activate()
    m.nav.index = 0
    if settingsSig() <> m.loadedSig then
        load()
        return
    end if
    if m.loaded then
        m.watch = WatchLoad()
        if watchSignature() <> m.watchSig then buildRows()
        m.rows.setFocus(true)
    else if m.retry.visible then
        m.retry.setFocus(true)
    else
        m.nav.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "up" and m.rows.isInFocusChain() then
        f = m.rows.rowItemFocused
        if f <> invalid and f[0] = 0 then
            m.nav.setFocus(true)
            return true
        end if
    else if key = "back" and not m.nav.isInFocusChain() then
        m.nav.setFocus(true)
        return true
    else if key = "down" and m.nav.isInFocusChain() then
        if m.rows.visible then
            m.rows.setFocus(true)
        else if m.retry.visible then
            m.retry.setFocus(true)
        end if
        return true
    else if key = "up" and m.retry.isInFocusChain() then
        m.nav.setFocus(true)
        return true
    end if
    return false
end function
