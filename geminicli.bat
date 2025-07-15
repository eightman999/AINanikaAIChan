@echo off
set DIR=%~dp0
if exist "%DIR%geminicli.py" (
    python "%DIR%geminicli.py" %*
    goto :eof
)
if exist "%DIR%geminicli.csx" (
    dotnet script "%DIR%geminicli.csx" %*
    goto :eof
)
echo GeminiCLI not found
exit /b 1
