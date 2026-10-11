' Cuerpo de la tarea: ejecuta la petición y publica la respuesta (lo que dispara el observador del llamante).
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    req = m.top.request
    res = ApiExecute(req)
    m.top.response = res
end sub
