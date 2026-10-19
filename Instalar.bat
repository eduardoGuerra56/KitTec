@echo off
setlocal
title KitTec

REM ============================================================
REM  KitTec - inicializador
REM  1) Pede permissao de administrador (se ainda nao tiver)
REM  2) Executa o Instalar.ps1 que esta na mesma pasta
REM  Uso: Instalar.bat            -> abre a janela de selecao
REM       Instalar.bat -Padrao    -> instala os apps marcados como padrao, sem menu
REM       Instalar.bat -Todos     -> instala todos os apps da lista, sem menu
REM       Instalar.bat -Padrao -Categoria Suporte  (Geral, Suporte, Dev ou Tudo)
REM ============================================================

REM Pasta onde este .bat esta (termina com \)
set "PASTA=%~dp0"
set "SCRIPT=%PASTA%Instalar.ps1"

REM --- 1) Verifica se esta rodando como administrador ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permissao de administrador...
    if "%~1"=="" (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)

REM --- 2) Confere se o script PowerShell existe ---
if not exist "%SCRIPT%" (
    echo ERRO: Instalar.ps1 nao encontrado em:
    echo %SCRIPT%
    pause
    exit /b 1
)

REM --- 3) Sem parametros: abre a janela e fecha este console ---
if "%~1"=="" (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%"
    exit /b 0
)

REM --- 4) Com -Padrao ou -Todos: roda no console (Bypass vale so para esta execucao) ---
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "CODIGO=%errorlevel%"

echo.
if %CODIGO% neq 0 (
    echo Concluido com falhas. Veja o log na pasta "logs".
) else (
    echo Concluido com sucesso.
)
pause
exit /b %CODIGO%
