' Barra de botones: izquierda/derecha cambia el botón, OK lo selecciona (campo selected).
' Arriba/abajo/atrás no se consumen: los trata la pantalla que contiene la barra.

sub init()
    m.pills = []
    m.labels = []
    m.lines = []
    m.top.observeField("focusedChild", "redraw")
end sub

sub rebuild()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    m.pills = []
    m.labels = []
    m.lines = []
    items = m.top.items
    if items = invalid then return
    w = m.top.itemWidth
    h = m.top.barHeight
    for i = 0 to items.Count() - 1
        x = i * (w + m.top.gap)
        pill = CreateObject("roSGNode", "Rectangle")
        pill.translation = [x, 0]
        pill.width = w
        pill.height = h
        pill.color = "0x00000000"
        lbl = CreateObject("roSGNode", "Label")
        lbl.translation = [x, 0]
        lbl.width = w
        lbl.height = h
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        lbl.font = "font:MediumBoldSystemFont"
        lbl.text = items[i]
        line = CreateObject("roSGNode", "Rectangle")
        line.translation = [x + 24, h - 6]
        line.width = w - 48
        line.height = 4
        line.color = "0xEC4899FF"
        line.visible = false
        m.top.appendChild(pill)
        m.top.appendChild(line)
        m.top.appendChild(lbl)
        m.pills.Push(pill)
        m.labels.Push(lbl)
        m.lines.Push(line)
    end for
    redraw()
end sub

sub redraw()
    if m.pills = invalid then return
    focused = m.top.isInFocusChain()
    for i = 0 to m.pills.Count() - 1
        isFocus = focused and i = m.top.index
        if isFocus then
            m.pills[i].color = "0xEC4899FF"
            m.labels[i].color = "0xFFFFFFFF"
        else
            if m.top.filled then
                m.pills[i].color = "0x26263DFF"
            else
                m.pills[i].color = "0x00000000"
            end if
            if i = m.top.activeIndex then
                m.labels[i].color = "0xFFFFFFFF"
            else
                m.labels[i].color = "0xB4B4C8FF"
            end if
        end if
        m.lines[i].visible = (i = m.top.activeIndex) and not isFocus
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.pills = invalid then return false
    n = m.pills.Count()
    if key = "right" then
        if m.top.index < n - 1 then m.top.index = m.top.index + 1
        return true
    else if key = "left" then
        if m.top.index > 0 then m.top.index = m.top.index - 1
        return true
    else if key = "OK" then
        m.top.selected = m.top.index
        return true
    end if
    return false
end function
