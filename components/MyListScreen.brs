' Mi lista. Con la tecla * (opciones) se quita el título enfocado.

sub init()
    m.nav = m.top.findNode("nav")
    m.title = m.top.findNode("title")
    m.grid = m.top.findNode("grid")
    m.status = m.top.findNode("status")
    m.focusTitle = m.top.findNode("focusTitle")
    m.hint = m.top.findNode("hint")

    m.nav.items = [Tx("nav_home"), Tx("nav_search"), Tx("nav_mylist"), Tx("nav_settings")]
    m.nav.activeIndex = 2
    m.nav.index = 2
    m.nav.observeField("selected", "onNav")
    m.title.text = Tx("nav_mylist")
    m.hint.text = Tx("mylist_hint")
    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")
    m.list = []
end sub

sub refresh()
    m.list = MyListLoad()
    if m.list.Count() = 0 then
        m.grid.content = invalid
        m.grid.visible = false
        m.status.text = Tx("mylist_empty")
        m.status.visible = true
        m.focusTitle.text = ""
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    for each it in m.list
        root.appendChild(MakeMediaNode(it))
    end for
    m.grid.content = root
    m.grid.visible = true
    m.status.visible = false
end sub

sub onItemFocused()
    i = m.grid.itemFocused
    if i >= 0 and i < m.list.Count() then m.focusTitle.text = NzStr(m.list[i].title)
end sub

sub onItemSelected()
    i = m.grid.itemSelected
    if i >= 0 and i < m.list.Count() then m.top.action = { type: "openDetail", item: m.list[i] }
end sub

sub onNav()
    m.top.action = { type: "nav", index: m.nav.selected }
end sub

sub activate()
    m.nav.index = 2
    refresh()
    if m.grid.visible then
        m.grid.setFocus(true)
    else
        m.nav.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "up" and m.grid.isInFocusChain() then
        if m.grid.itemFocused < 7 then
            m.nav.setFocus(true)
            return true
        end if
    else if key = "down" and m.nav.isInFocusChain() then
        if m.grid.visible then m.grid.setFocus(true)
        return true
    else if key = "options" and m.grid.isInFocusChain() then
        i = m.grid.itemFocused
        if i >= 0 and i < m.list.Count() then
            MyListToggle(m.list[i])
            refresh()
            if m.grid.visible then
                m.grid.setFocus(true)
            else
                m.nav.setFocus(true)
            end if
        end if
        return true
    end if
    return false
end function
