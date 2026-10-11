' Punto de entrada de las pruebas públicas (con el Plugins.brs neutro del repo).
sub Main()
    TestsInit()
    RunPublicTests()
    RunStubTests()
    TestsDone()
end sub
