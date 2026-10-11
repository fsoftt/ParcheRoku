' Navegación. Las pantallas no se conocen entre sí: cada una publica una acción (campo "action") y esta escena decide.
'
' Acciones: back, nav {index}, openDetail {item}, sources {item, season, episode, episodeTitle},
'           play {item, season, episode, episodeTitle, sources, index}, resume {entry}, playFailed {...},
'           settings, restart.

sub init()
    s = SettingsLoad()
    m.global.lang = s.uiLang
    m.roots = {}
    m.stack = []
    m.currentRoot = -1
    showRoot(0)
end sub

' Nombre del componente de cada pantalla raíz (mismo orden que el menú).
function rootName(index as integer) as string
    names = ["HomeScreen", "SearchScreen", "MyListScreen", "SettingsScreen"]
    return names[index]
end function

' Devuelve la pantalla que debe tener el foco ahora.
function topScreen() as object
    if m.stack.Count() > 0 then return m.stack[m.stack.Count() - 1]
    return m.roots[m.currentRoot.ToStr()]
end function

' ---------- raíces ----------

sub showRoot(index as integer)
    ' Cierra lo apilado (detalle, fuentes, reproductor).
    while m.stack.Count() > 0
        scr = m.stack.Pop()
        m.top.removeChild(scr)
    end while
    if m.currentRoot >= 0 then m.roots[m.currentRoot.ToStr()].visible = false
    m.currentRoot = index
    key = index.ToStr()
    if not m.roots.DoesExist(key) then
        scr = CreateObject("roSGNode", rootName(index))
        scr.observeField("action", "onAction")
        m.top.appendChild(scr)
        m.roots[key] = scr
    end if
    scr = m.roots[key]
    scr.visible = true
    scr.callFunc("activate")
end sub

' ---------- pila ----------

sub pushScreen(scr as object)
    topScreen().visible = false
    scr.observeField("action", "onAction")
    m.top.appendChild(scr)
    m.stack.Push(scr)
    scr.callFunc("activate")
end sub

sub popScreen()
    if m.stack.Count() = 0 then return
    scr = m.stack.Pop()
    m.top.removeChild(scr)
    t = topScreen()
    t.visible = true
    t.callFunc("activate")
end sub

' ---------- acciones ----------

sub onAction(event as object)
    a = event.getData()
    if a = invalid then return
    t = NzStr(a.type)
    if t = "back" then
        popScreen()
    else if t = "nav" then
        if ToInt(a.index) <> m.currentRoot or m.stack.Count() > 0 then showRoot(ToInt(a.index))
    else if t = "openDetail" then
        scr = CreateObject("roSGNode", "DetailScreen")
        scr.item = a.item
        pushScreen(scr)
    else if t = "sources" then
        openSources(a)
    else if t = "play" then
        openPlayer(a.item, a.season, a.episode, NzStr(a.episodeTitle), a.sources, a.index)
    else if t = "resume" then
        resumeEntry(a.entry)
    else if t = "playFailed" then
        onPlayFailed(a)
    else if t = "settings" then
        showRoot(3)
    else if t = "restart" then
        restartUi()
    end if
end sub

' Atras en una raiz distinta de Inicio vuelve a Inicio. En Inicio lo trata la pantalla (foco a la barra) y, ya en la barra, sale del canal.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "back" then return false
    if m.stack.Count() = 0 and m.currentRoot > 0 then
        showRoot(0)
        return true
    end if
    return false
end function

sub openSources(a as object)
    scr = CreateObject("roSGNode", "SourcePickerScreen")
    scr.request = { item: a.item, season: a.season, episode: a.episode, episodeTitle: NzStr(a.episodeTitle) }
    pushScreen(scr)
end sub

' Abre el reproductor retomando donde se dejó (si hay avance guardado para ese título/episodio).
sub openPlayer(item as object, season as dynamic, episode as dynamic, episodeTitle as string, sources as object, index as dynamic)
    startMs = 0
    e = CwFind(WatchLoad(), item, ToInt(season, -1), ToInt(episode, -1))
    if e <> invalid then startMs = ToInt(e.positionMs)
    scr = CreateObject("roSGNode", "PlayerScreen")
    scr.request = {
        item: item
        season: ToInt(season, -1)
        episode: ToInt(episode, -1)
        episodeTitle: episodeTitle
        sources: sources
        index: ToInt(index)
        startMs: startMs
    }
    pushScreen(scr)
end sub

' "Continuar viendo": reproduce directamente con la fuente guardada; si falla, se abre el selector.
sub resumeEntry(e as object)
    if e.source = invalid then
        openSources({ item: e.item, season: ToInt(e.season, -1), episode: ToInt(e.episode, -1), episodeTitle: NzStr(e.episodeTitle) })
        return
    end if
    src = {
        url: NzStr(e.source.url)
        headers: e.source.headers
        quality: NzStr(e.source.quality, "")
    }
    if type(src.headers) <> "roAssociativeArray" then src.headers = {}
    scr = CreateObject("roSGNode", "PlayerScreen")
    scr.request = {
        item: e.item
        season: ToInt(e.season, -1)
        episode: ToInt(e.episode, -1)
        episodeTitle: NzStr(e.episodeTitle)
        sources: [src]
        index: 0
        startMs: ToInt(e.positionMs)
    }
    pushScreen(scr)
end sub

sub onPlayFailed(a as object)
    popScreen() ' quita el reproductor
    if a.fromPicker then
        OpenMessageDialog(Tx("player_failed_title"), [Tx("player_failed")], m.top)
    else
        openSources({ item: a.item, season: a.season, episode: a.episode, episodeTitle: NzStr(a.episodeTitle) })
    end if
end sub

' Cambio de idioma: se descartan todas las pantallas para reconstruirlas con los textos nuevos.
sub restartUi()
    while m.stack.Count() > 0
        scr = m.stack.Pop()
        m.top.removeChild(scr)
    end while
    for each k in m.roots
        m.top.removeChild(m.roots[k])
    end for
    m.roots = {}
    m.currentRoot = -1
    showRoot(3)
end sub

