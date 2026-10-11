' Cuerpo de la tarea: escribe el avance en "Continuar viendo" (lectura + escritura + Flush del registro) sin
' bloquear el hilo de render.
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    WatchReport(m.top.entry)
end sub
