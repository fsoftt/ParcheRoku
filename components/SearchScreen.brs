' Búsqueda con retardo (0,8 s tras la última tecla) para no consultar en cada letra.

sub init()
    m.nav = m.top.findNode("nav")
    m.title = m.top.findNode("title")
    m.keyboard = m.top.findNode("keyboard")
    m.hint = m.top.findNode("hint")
    m.grid = m.top.findNode("grid")
    m.status = m.top.findNode("status")
    m.focusTitle = m.top.findNode("focusTitle")
    m.debounce = m.top.findNode("debounce")

    m.nav.items = [Tx("nav_home"), Tx("nav_search"), Tx("nav_mylist"), Tx("nav_settings")]
    m.nav.activeIndex = 1
    m.nav.index = 1
    m.nav.observeField("selected", "onNav")
    m.title.text = Tx("search_title")
    m.hint.text = Tx("search_hint")
    m.status.text = Tx("search_prompt")
    m.keyboard.observeField("text", "onText")
    m.debounce.observeField("fire", "onDebounce")
    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")
    m.pendingId = -1
    m.lastQuery = ""
end sub

sub onText()
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub onDebounce()
    q = m.keyboard.text.Trim()
    if q = m.lastQuery then return
    m.lastQuery = q
    if Len(q) < 2 then
        m.grid.content = invalid
        m.focusTitle.text = ""
        m.status.text = Tx("search_prompt")
        m.status.visible = true
        m.pendingId = -1
        return
    end if
    m.status.text = Tx("loading")
    m.status.visible = true
    m.pendingId = ApiRequest({ kind: "search", query: q }, "onResults")
end sub

sub onResults(event as object)
    res = ApiTake(event)
    if res.reqId <> m.pendingId then return
    if not res.ok then
        m.status.text = Tx("err_search") + chr(10) + res.error
        return
    end if
    items = res.data.items
    if items.Count() = 0 then
        m.grid.content = invalid
        m.status.text = Tx("search_empty", m.lastQuery)
        m.status.visible = true
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    for each it in items
        root.appendChild(MakeMediaNode(it))
    end for
    m.grid.content = root
    m.status.visible = false
end sub

sub onItemFocused()
    i = m.grid.itemFocused
    root = m.grid.content
    if root = invalid or i < 0 then return
    node = root.getChild(i)
    if node <> invalid then
        t = NzStr(node.media.title)
        if ToInt(node.media.year) > 0 then t = t + " (" + node.media.year.ToStr() + ")"
        m.focusTitle.text = t
    end if
end sub

sub onItemSelected()
    root = m.grid.content
    if root = invalid then return
    node = root.getChild(m.grid.itemSelected)
    if node <> invalid then m.top.action = { type: "openDetail", item: node.media }
end sub

sub onNav()
    m.top.action = { type: "nav", index: m.nav.selected }
end sub

sub activate()
    m.nav.index = 1
    m.keyboard.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "up" then
        if m.keyboard.isInFocusChain() or m.grid.isInFocusChain() then
            m.nav.setFocus(true)
            return true
        end if
    else if key = "down" and m.nav.isInFocusChain() then
        m.keyboard.setFocus(true)
        return true
    else if key = "right" and m.keyboard.isInFocusChain() then
        if m.grid.content <> invalid then
            m.grid.setFocus(true)
            return true
        end if
    else if key = "left" and m.grid.isInFocusChain() then
        m.keyboard.setFocus(true)
        return true
    end if
    return false
end function
