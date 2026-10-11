' Punto de entrada del canal Parche Roku.
' Crea la pantalla SceneGraph y espera hasta que se cierre.
sub Main(args as dynamic)
    if args <> invalid then print "[Parche] arranque con argumentos"
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    ' Campos globales (accesibles desde cualquier nodo y tarea): idioma de la interfaz.
    screen.GetGlobalNode().AddFields({ lang: "es" })

    screen.CreateScene("MainScene")
    screen.Show()

    ' Registro de entrada (deep links / comandos de voz): lo exigen las certificaciones de Roku.
    input = CreateObject("roInput")
    input.SetMessagePort(port)

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" then
            if msg.IsScreenClosed() then return
        end if
    end while
end sub
