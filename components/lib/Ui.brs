' Ayudas de interfaz compartidas por las pantallas (se ejecutan en el hilo de render, en el ámbito del componente
' que las incluye: "m" es el de la pantalla que las llama).

' ---------- peticiones a ApiTask ----------

' Lanza una petición en un ApiTask nuevo; callback es el nombre de la función de la pantalla que recibe la
' respuesta. Devuelve el id de la petición (para descartar respuestas viejas).
function ApiRequest(req as object, callback as string) as integer
    m.reqSeq = ToInt(m.reqSeq) + 1
    req.reqId = m.reqSeq
    if req.settings = invalid then req.settings = SettingsLoad()
    task = CreateObject("roSGNode", "ApiTask")
    task.request = req
    task.observeField("response", callback)
    if m.apiTasks = invalid then m.apiTasks = {}
    m.apiTasks[req.reqId.ToStr()] = task
    task.control = "RUN"
    return req.reqId
end function

' Recoge la respuesta de un evento de ApiTask y libera la tarea.
function ApiTake(event as object) as object
    res = event.getData()
    if m.apiTasks <> invalid and res <> invalid then m.apiTasks.Delete(NzStr(res.reqId))
    return res
end function

' ---------- nodos de contenido ----------

' MediaNode para un título (progress 0..1 para la barra de "Continuar viendo").
function MakeMediaNode(item as object, progress = 0.0 as float) as object
    n = CreateObject("roSGNode", "MediaNode")
    n.title = NzStr(item.title)
    poster = NzStr(item.poster)
    if poster = "" then poster = NzStr(item.backdrop)
    n.HDPosterUrl = poster
    n.media = item
    n.progress = progress
    return n
end function

' RowNode de texto (ajustes, temporadas, fuentes).
function MakeRowNode(title as string, line2 = "" as string, right = "" as string, rightColor = "0x9CA3AFFF" as string) as object
    n = CreateObject("roSGNode", "RowNode")
    n.title = title
    n.line2 = line2
    n.right = right
    n.rightColor = rightColor
    return n
end function

' Línea de datos de un título: "2019 · 8.4 · Drama, Crimen".
function MetaLine(item as object) as string
    bullet = " " + Chr(183) + " "
    parts = []
    if ToInt(item.year) > 0 then parts.Push(item.year.ToStr())
    if ToFloat(item.rating) > 0 then parts.Push(Fmt1(item.rating))
    if IsNum(item.runtime) then
        if item.runtime > 0 then parts.Push(FormatMinutes(item.runtime))
    end if
    if type(item.genres) = "roArray" then
        g = []
        for each x in item.genres
            if g.Count() < 3 then g.Push(x)
        end for
        if g.Count() > 0 then parts.Push(ArrayJoin(g, ", "))
    end if
    if NzStr(item.type) = "series" then parts.Push(Tx("type_series")) else parts.Push(Tx("type_movie"))
    return ArrayJoin(parts, bullet)
end function

' Crea una etiqueta de texto (para mensajes dinámicos).
function MakeLabel(text as string, x as integer, y as integer, w as integer, h as integer, font as string, color as string) as object
    l = CreateObject("roSGNode", "Label")
    l.translation = [x, y]
    l.width = w
    l.height = h
    l.font = font
    l.color = color
    l.text = text
    l.wrap = true
    return l
end function

' Abre un diálogo de teclado estándar; el llamante observa buttonSelected y lee dlg.text.
function OpenKeyboardDialog(title as string, message as string, text as string, owner as object, callback as string) as object
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = title
    dlg.message = [message]
    dlg.text = text
    dlg.buttons = [Tx("btn_save"), Tx("btn_cancel")]
    dlg.observeFieldScoped("buttonSelected", callback)
    owner.getScene().dialog = dlg
    return dlg
end function

' Abre un diálogo de mensaje con un botón de cierre.
sub OpenMessageDialog(title as string, lines as object, owner as object)
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = title
    dlg.message = lines
    dlg.buttons = [Tx("btn_close")]
    dlg.observeFieldScoped("buttonSelected", "onDialogClose")
    owner.getScene().dialog = dlg
end sub

sub onDialogClose()
    d = m.top.getScene().dialog
    if d <> invalid then d.close = true
end sub
