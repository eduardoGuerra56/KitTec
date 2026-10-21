<#
.SYNOPSIS
    Instala e desinstala varios programas de uma vez usando o winget, com interface grafica.

.DESCRIPTION
    Le a lista de programas do arquivo apps.json e abre uma janela com duas abas:
    Instalar e Desinstalar. Pula o que ja estiver (ou nao estiver) instalado,
    mostra o status de cada programa e salva um log na pasta "logs".

.PARAMETER Padrao
    Sem janela: instala os programas marcados com "padrao": true no apps.json.

.PARAMETER Todos
    Sem janela: instala todos os programas do apps.json.

.PARAMETER Categoria
    Usado com -Padrao ou -Todos: Geral (padrao), Suporte, Dev ou Tudo.

.PARAMETER Lista
    Caminho de outro arquivo .json com a lista de programas.

.EXAMPLE
    .\Instalar.ps1
    .\Instalar.ps1 -Padrao
    .\Instalar.ps1 -Padrao -Categoria Suporte
    .\Instalar.ps1 -Todos -Lista .\apps-escritorio.json
#>
[CmdletBinding()]
param(
    [switch]$Padrao,
    [switch]$Todos,
    [string]$Categoria = 'Geral',
    [string]$Lista
)

# 'Continue' evita que mensagens do winget sejam tratadas como erro fatal no PowerShell 5.1
$ErrorActionPreference = 'Continue'

# No PowerShell 5.1 o $PSScriptRoot fica vazio dentro do param(), por isso os caminhos sao definidos aqui
$Base = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $Lista) { $Lista = Join-Path $Base 'apps.json' }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================================================================== Log
$pastaLog = Join-Path $Base 'logs'
New-Item -ItemType Directory -Path $pastaLog -Force | Out-Null
$arquivoLog = Join-Path $pastaLog ("instalacao_{0:yyyy-MM-dd_HH-mm-ss}.log" -f (Get-Date))

function Log([string]$Texto) {
    $linha = "{0:HH:mm:ss}  {1}" -f (Get-Date), $Texto
    Add-Content -Path $arquivoLog -Value $linha -Encoding UTF8
}

function Avisar([string]$Texto, [bool]$ModoJanela) {
    Log $Texto
    if ($ModoJanela) {
        [System.Windows.Forms.MessageBox]::Show($Texto, 'KitTec', 'OK', 'Error') | Out-Null
    } else {
        Write-Host $Texto -ForegroundColor Red
    }
}

$modoJanela = -not ($Padrao -or $Todos)

# ================================================================== Verificacoes
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Avisar 'Execute como administrador (use o Instalar.bat).' $modoJanela
    exit 1
}

$cmdWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $cmdWinget) {
    Avisar ("O winget nao foi encontrado neste computador.`n`n" +
            'Instale ou atualize o "Instalador de Aplicativo" (App Installer) pela Microsoft Store e tente de novo.') $modoJanela
    exit 1
}
$winget = $cmdWinget.Source

if (-not (Test-Path $Lista)) {
    Avisar "Lista de programas nao encontrada:`n$Lista" $modoJanela
    exit 1
}

try {
    $json = Get-Content -Path $Lista -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $apps = @($json | ForEach-Object { $_ })   # garante uma lista (PowerShell 5.1)
    # Programas sem categoria entram na aba Instalar (Geral)
    foreach ($a in $apps) {
        if (-not $a.PSObject.Properties['categoria'] -or -not $a.categoria) {
            $a | Add-Member -NotePropertyName categoria -NotePropertyValue 'Geral' -Force
        }
    }
} catch {
    Avisar "O arquivo de lista tem um erro de formatacao (JSON invalido):`n$Lista" $modoJanela
    exit 1
}

# ================================================================== Winget
# Roda o winget escondido e devolve o codigo de saida, sem travar a janela
function Executar-Winget([string[]]$Argumentos) {
    $p = Start-Process -FilePath $winget -ArgumentList $Argumentos -WindowStyle Hidden -PassThru
    $null = $p.Handle   # necessario para o ExitCode ficar disponivel depois
    while (-not $p.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }
    $p.WaitForExit()
    return $p.ExitCode
}

function Esta-Instalado([string]$Id) {
    $codigo = Executar-Winget @('list', '--id', $Id, '--exact', '--accept-source-agreements')
    return ($codigo -eq 0)
}

function Instalar-App([string]$Id) {
    return (Executar-Winget @('install', '--id', $Id, '--exact', '--silent',
                              '--accept-package-agreements', '--accept-source-agreements'))
}

function Desinstalar-App([string]$Id) {
    return (Executar-Winget @('uninstall', '--id', $Id, '--exact', '--silent', '--accept-source-agreements'))
}

# ================================================================== Modo sem janela (-Padrao / -Todos)
if (-not $modoJanela) {
    $daCategoria  = if ($Categoria -eq 'Tudo') { $apps } else { @($apps | Where-Object { $_.categoria -eq $Categoria }) }
    $selecionados = if ($Todos) { $daCategoria } else { @($daCategoria | Where-Object { $_.padrao }) }
    $falhas = 0
    $n = 0
    foreach ($app in $selecionados) {
        $n++
        Write-Host ("[{0}/{1}] {2}" -f $n, $selecionados.Count, $app.nome) -ForegroundColor Cyan
        if (Esta-Instalado $app.id) {
            Write-Host '      Ja instalado.' -ForegroundColor DarkGray
            Log "$($app.nome): ja instalado"
            continue
        }
        $codigo = Instalar-App $app.id
        if ($codigo -eq 0) {
            Write-Host '      Instalado.' -ForegroundColor Green
            Log "$($app.nome): instalado"
        } else {
            $falhas++
            Write-Host "      Falhou (codigo $codigo)." -ForegroundColor Red
            Log "$($app.nome): FALHOU (codigo $codigo)"
        }
    }
    Write-Host "Log: $arquivoLog" -ForegroundColor DarkGray
    if ($falhas -gt 0) { exit 1 } else { exit 0 }
}

# ================================================================== Janela
[System.Windows.Forms.Application]::EnableVisualStyles()

# Cores e fontes
$corFundo       = [System.Drawing.Color]::FromArgb(245, 247, 250)
$corCabecalho   = [System.Drawing.Color]::FromArgb(11, 34, 64)
$corBarraAbas   = [System.Drawing.Color]::FromArgb(22, 52, 92)
$corAbaHover    = [System.Drawing.Color]::FromArgb(34, 70, 118)
$corDestaque    = [System.Drawing.Color]::FromArgb(31, 111, 224)
$corPerigo      = [System.Drawing.Color]::FromArgb(198, 40, 40)
$corTextoSec    = [System.Drawing.Color]::FromArgb(185, 205, 230)
$corSucesso     = [System.Drawing.Color]::FromArgb(22, 135, 70)
$corErro        = [System.Drawing.Color]::FromArgb(200, 40, 40)
$corNeutra      = [System.Drawing.Color]::FromArgb(110, 118, 130)
$corAndamento   = [System.Drawing.Color]::FromArgb(31, 111, 224)
$corLinha       = [System.Drawing.Color]::FromArgb(228, 232, 238)
$corSelecao     = [System.Drawing.Color]::FromArgb(232, 241, 253)
$corTextoEscuro = [System.Drawing.Color]::FromArgb(11, 34, 64)
$corPlaceholder = [System.Drawing.Color]::FromArgb(140, 150, 165)

$fonte        = New-Object System.Drawing.Font('Segoe UI', 10)
$fonteTitulo  = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
$fonteNegrito = New-Object System.Drawing.Font('Segoe UI Semibold', 10)

# Abas: nome na tela, categoria do apps.json e tipo de acao
$abas = @(
    [pscustomobject]@{ Nome = 'Instalar';        Categoria = 'Geral';   Acao = 'instalar';    Subtitulo = 'Programas do dia a dia. Marque e clique em Instalar' },
    [pscustomobject]@{ Nome = 'Suporte Tecnico'; Categoria = 'Suporte'; Acao = 'instalar';    Subtitulo = 'Ferramentas de diagnostico e suporte tecnico' },
    [pscustomobject]@{ Nome = 'Dev Apps';        Categoria = 'Dev';     Acao = 'instalar';    Subtitulo = 'Ferramentas para TI e desenvolvimento' },
    [pscustomobject]@{ Nome = 'Desinstalar';     Categoria = '';        Acao = 'desinstalar'; Subtitulo = 'Programas da lista instalados neste computador' }
)

$script:abaAtual    = $abas[0]
$script:ocupado     = $false
$script:houveFalha  = $false
$script:verificado  = $false     # ja verificou o que esta instalado?
$script:instalado   = @{}        # id do app -> $true / $false
$script:placeholder = $true      # caixa de pesquisa mostrando o texto de exemplo?
$textoPesquisa      = 'Pesquisar app...'

# --- Formulario
$form = New-Object System.Windows.Forms.Form
$form.Text            = 'KitTec'
$form.ClientSize      = New-Object System.Drawing.Size(640, 640)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox     = $false
$form.BackColor       = $corFundo
$form.Font            = $fonte

# --- Cabecalho
$cabecalho = New-Object System.Windows.Forms.Panel
$cabecalho.Location  = New-Object System.Drawing.Point(0, 0)
$cabecalho.Size      = New-Object System.Drawing.Size(640, 78)
$cabecalho.BackColor = $corCabecalho
$form.Controls.Add($cabecalho)

$titulo = New-Object System.Windows.Forms.Label
$titulo.Text      = 'KitTec'
$titulo.Font      = $fonteTitulo
$titulo.ForeColor = [System.Drawing.Color]::White
$titulo.AutoSize  = $true
$titulo.Location  = New-Object System.Drawing.Point(20, 12)
$cabecalho.Controls.Add($titulo)

$subtitulo = New-Object System.Windows.Forms.Label
$subtitulo.ForeColor = $corTextoSec
$subtitulo.AutoSize  = $true
$subtitulo.Location  = New-Object System.Drawing.Point(22, 46)
$cabecalho.Controls.Add($subtitulo)

# --- Pesquisa (canto superior direito)
$pesquisa = New-Object System.Windows.Forms.TextBox
$pesquisa.Location    = New-Object System.Drawing.Point(410, 16)
$pesquisa.Size        = New-Object System.Drawing.Size(210, 26)
$pesquisa.BorderStyle = 'FixedSingle'
$pesquisa.Text        = $textoPesquisa
$pesquisa.ForeColor   = $corPlaceholder
$cabecalho.Controls.Add($pesquisa)

function Termo-Pesquisa {
    if ($script:placeholder) { return '' }
    return $pesquisa.Text.Trim()
}

# --- Barra de abas
$barraAbas = New-Object System.Windows.Forms.Panel
$barraAbas.Location  = New-Object System.Drawing.Point(0, 78)
$barraAbas.Size      = New-Object System.Drawing.Size(640, 44)
$barraAbas.BackColor = $corBarraAbas
$form.Controls.Add($barraAbas)

$botoesAba = @{}
$xAba = 20
foreach ($aba in $abas) {
    $largura = [Math]::Max(100, [System.Windows.Forms.TextRenderer]::MeasureText($aba.Nome, $fonteNegrito).Width + 32)
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $aba.Nome
    $b.Location  = New-Object System.Drawing.Point($xAba, 6)
    $b.Size      = New-Object System.Drawing.Size($largura, 38)
    $b.FlatStyle = 'Flat'
    $b.Font      = $fonteNegrito
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.Tag       = $aba
    $b.FlatAppearance.BorderSize = 0
    $barraAbas.Controls.Add($b)
    $botoesAba[$aba.Nome] = $b
    $xAba += $largura + 4
}

function Pintar-Abas {
    foreach ($aba in $abas) {
        $b = $botoesAba[$aba.Nome]
        if ($aba.Nome -eq $script:abaAtual.Nome) {
            $b.BackColor = $corFundo
            $b.ForeColor = $corTextoEscuro
            $b.FlatAppearance.MouseOverBackColor = $corFundo
        } else {
            $b.BackColor = $corBarraAbas
            $b.ForeColor = $corTextoSec
            $b.FlatAppearance.MouseOverBackColor = $corAbaHover
        }
    }
}

# --- Tabela de programas (coluna de marcar, nome e status)
$grade = New-Object System.Windows.Forms.DataGridView
$grade.Location                 = New-Object System.Drawing.Point(20, 138)
$grade.Size                     = New-Object System.Drawing.Size(600, 312)
$grade.AllowUserToAddRows       = $false
$grade.AllowUserToDeleteRows    = $false
$grade.AllowUserToResizeRows    = $false
$grade.AllowUserToResizeColumns = $false
$grade.RowHeadersVisible        = $false
$grade.MultiSelect              = $false
$grade.SelectionMode            = 'FullRowSelect'
$grade.BackgroundColor          = [System.Drawing.Color]::White
$grade.BorderStyle              = 'FixedSingle'
$grade.CellBorderStyle          = 'SingleHorizontal'
$grade.GridColor                = $corLinha
$grade.EnableHeadersVisualStyles   = $false
$grade.ColumnHeadersBorderStyle    = 'None'
$grade.ColumnHeadersHeightSizeMode = 'DisableResizing'
$grade.ColumnHeadersHeight         = 34
$grade.ColumnHeadersDefaultCellStyle.BackColor = $corFundo
$grade.ColumnHeadersDefaultCellStyle.ForeColor = $corNeutra
$grade.ColumnHeadersDefaultCellStyle.Font      = $fonteNegrito
$grade.ColumnHeadersDefaultCellStyle.SelectionBackColor = $corFundo
$grade.DefaultCellStyle.SelectionBackColor = $corSelecao
$grade.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
$grade.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
$grade.RowTemplate.Height = 32

$colMarcar = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colMarcar.HeaderText = ''
$colMarcar.Width      = 44
$colMarcar.SortMode   = 'NotSortable'

$colNome = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colNome.HeaderText   = 'Programa'
$colNome.ReadOnly     = $true
$colNome.AutoSizeMode = 'Fill'
$colNome.SortMode     = 'NotSortable'

$colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colStatus.HeaderText = 'Status'
$colStatus.ReadOnly   = $true
$colStatus.Width      = 170
$colStatus.SortMode   = 'NotSortable'

[void]$grade.Columns.Add($colMarcar)
[void]$grade.Columns.Add($colNome)
[void]$grade.Columns.Add($colStatus)

foreach ($app in ($apps | Sort-Object nome)) {
    $indice = $grade.Rows.Add()
    $linha  = $grade.Rows[$indice]
    $linha.Cells[0].Value = $false   # tudo desmarcado ao abrir
    $linha.Cells[1].Value = [string]$app.nome
    $linha.Cells[2].Value = ''
    $linha.Tag = $app
}
$form.Controls.Add($grade)

# Mensagem quando a lista fica vazia (pesquisa sem resultado, nada instalado...)
$vazio = New-Object System.Windows.Forms.Label
$vazio.AutoSize  = $false
$vazio.Size      = New-Object System.Drawing.Size(560, 60)
$vazio.Location  = New-Object System.Drawing.Point(40, 260)
$vazio.TextAlign = 'MiddleCenter'
$vazio.ForeColor = $corNeutra
$vazio.BackColor = [System.Drawing.Color]::White
$vazio.Visible   = $false
$form.Controls.Add($vazio)
$vazio.BringToFront()

# --- Regras de quais linhas aparecem
function Pertence-AbaAtual($Linha) {
    if ($script:abaAtual.Acao -eq 'desinstalar') {
        return ($script:instalado[$Linha.Tag.id] -eq $true)
    }
    return ($Linha.Tag.categoria -eq $script:abaAtual.Categoria)
}

function Linhas-DaAba {
    return @($grade.Rows | Where-Object { Pertence-AbaAtual $_ })
}

function Linhas-Visiveis {
    return @($grade.Rows | Where-Object { $_.Visible })
}

function Linhas-Marcadas {
    return @(Linhas-DaAba | Where-Object { $_.Cells[0].Value -eq $true })
}

function Aplicar-Filtro {
    $termo = Termo-Pesquisa
    $grade.CurrentCell = $null   # evita erro ao esconder a linha selecionada
    foreach ($l in $grade.Rows) {
        $passaPesquisa = ($termo -eq '') -or $l.Tag.nome.StartsWith($termo, [System.StringComparison]::OrdinalIgnoreCase)
        $l.Visible = (Pertence-AbaAtual $l) -and $passaPesquisa
    }
    $quantos = (Linhas-Visiveis).Count
    if ($quantos -eq 0) {
        if ($termo -ne '') {
            $vazio.Text = "Nenhum programa comeca com `"$termo`"."
        } elseif ($script:abaAtual.Acao -eq 'desinstalar') {
            $vazio.Text = 'Nenhum programa da lista esta instalado neste computador.'
        } else {
            $vazio.Text = 'Nenhum programa nesta aba.'
        }
        $vazio.Visible = $true
    } else {
        $vazio.Visible = $false
    }
}

# --- Progresso e status
$progresso = New-Object System.Windows.Forms.ProgressBar
$progresso.Location = New-Object System.Drawing.Point(20, 514)
$progresso.Size     = New-Object System.Drawing.Size(600, 14)
$form.Controls.Add($progresso)

$status = New-Object System.Windows.Forms.Label
$status.Location  = New-Object System.Drawing.Point(20, 536)
$status.Size      = New-Object System.Drawing.Size(600, 90)
$status.ForeColor = $corNeutra
$form.Controls.Add($status)

function Atualizar-Contagem {
    if ($script:ocupado) { return }
    $status.ForeColor = $corNeutra
    $verbo = if ($script:abaAtual.Acao -eq 'desinstalar') { 'desinstalar' } else { 'instalar' }
    $status.Text = "{0} de {1} programas selecionados para {2}." -f (Linhas-Marcadas).Count, (Linhas-DaAba).Count, $verbo
}

# --- Eventos da pesquisa (texto de exemplo + filtro a cada letra)
$pesquisa.Add_GotFocus({
    if ($script:placeholder) {
        $script:placeholder = $false
        $pesquisa.Text      = ''
        $pesquisa.ForeColor = [System.Drawing.Color]::Black
    }
})
$pesquisa.Add_LostFocus({
    if ($pesquisa.Text.Trim() -eq '') {
        $script:placeholder = $true
        $pesquisa.Text      = $textoPesquisa
        $pesquisa.ForeColor = $corPlaceholder
    }
})
$pesquisa.Add_TextChanged({
    if (-not $script:placeholder) { Aplicar-Filtro }
})
$pesquisa.Add_KeyDown({
    param($origem, $e)
    if ($e.KeyCode -eq 'Escape') { $pesquisa.Text = '' }
})

# --- Eventos da tabela
$grade.Add_CurrentCellDirtyStateChanged({
    if ($grade.IsCurrentCellDirty) { $grade.CommitEdit('CurrentCellChange') | Out-Null }
})
$grade.Add_CellClick({
    param($origem, $e)
    if ($e.RowIndex -ge 0 -and $e.ColumnIndex -gt 0 -and -not $grade.Columns[0].ReadOnly) {
        $celula = $grade.Rows[$e.RowIndex].Cells[0]
        $celula.Value = -not [bool]$celula.Value
    }
})
$grade.Add_CellValueChanged({
    param($origem, $e)
    if ($e.ColumnIndex -eq 0) { Atualizar-Contagem }
})

# --- Botoes
function Novo-Botao([string]$Texto, [int]$X, [int]$Largura, [bool]$Principal) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $Texto
    $b.Location  = New-Object System.Drawing.Point($X, 462)
    $b.Size      = New-Object System.Drawing.Size($Largura, 36)
    $b.FlatStyle = 'Flat'
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    if ($Principal) {
        $b.BackColor = $corDestaque
        $b.ForeColor = [System.Drawing.Color]::White
        $b.Font      = $fonteNegrito
        $b.FlatAppearance.BorderSize = 0
    } else {
        $b.BackColor = [System.Drawing.Color]::White
        $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(200, 205, 212)
    }
    $form.Controls.Add($b)
    return $b
}

$btnSugestao = Novo-Botao 'Recomendados' 20  120 $false
$btnTodos    = Novo-Botao 'Todos'        148 80  $false
$btnNenhum   = Novo-Botao 'Nenhum'       236 80  $false
$btnAcao     = Novo-Botao 'Instalar'     480 140 $true

# Recomendados: marca os "padrao" da aba (na aba Desinstalar vira "Atualizar")
$btnSugestao.Add_Click({
    if ($script:abaAtual.Acao -eq 'desinstalar') {
        Verificar-Instalados
        return
    }
    foreach ($l in Linhas-DaAba) { $l.Cells[0].Value = [bool]$l.Tag.padrao }
})
# Todos / Nenhum: valem para o que esta aparecendo (respeita a pesquisa)
$btnTodos.Add_Click({  foreach ($l in Linhas-Visiveis) { $l.Cells[0].Value = $true } })
$btnNenhum.Add_Click({ foreach ($l in Linhas-Visiveis) { $l.Cells[0].Value = $false } })

function Definir-Status($Linha, [string]$Texto, $Cor) {
    $Linha.Cells[2].Value           = $Texto
    $Linha.Cells[2].Style.ForeColor = $Cor
    $Linha.Cells[2].Style.SelectionForeColor = $Cor
    [System.Windows.Forms.Application]::DoEvents()
}

function Limpar-Status {
    foreach ($l in $grade.Rows) {
        $l.Cells[2].Value = ''
        $l.Cells[2].Style.ForeColor = $corNeutra
    }
}

function Travar([bool]$Travado) {
    $script:ocupado = $Travado
    $grade.Columns[0].ReadOnly = $Travado
    $controles = @($btnSugestao, $btnTodos, $btnNenhum, $btnAcao, $pesquisa) + @($botoesAba.Values)
    foreach ($c in $controles) { $c.Enabled = -not $Travado }
    $form.Cursor = if ($Travado) { [System.Windows.Forms.Cursors]::WaitCursor } else { [System.Windows.Forms.Cursors]::Default }
}

# Verifica quais programas (de todas as abas) estao instalados.
# Durante a verificacao mostra todos; no final ficam so os instalados.
function Verificar-Instalados {
    Travar $true
    $vazio.Visible = $false
    $grade.CurrentCell = $null
    foreach ($l in $grade.Rows) {
        $l.Visible = $true
        $l.Cells[0].Value = $false
        $l.Cells[2].Value = ''
    }
    $progresso.Maximum = [Math]::Max(1, $grade.Rows.Count)
    $progresso.Value   = 0
    foreach ($l in $grade.Rows) {
        try { $grade.FirstDisplayedScrollingRowIndex = $l.Index } catch { }
        $status.ForeColor = $corNeutra
        $status.Text = "Verificando o que esta instalado: $($l.Tag.nome)..."
        Definir-Status $l 'Verificando...' $corAndamento
        $sim = Esta-Instalado $l.Tag.id
        $script:instalado[$l.Tag.id] = $sim
        if ($sim) { Definir-Status $l 'Instalado' $corSucesso } else { Definir-Status $l 'Nao instalado' $corNeutra }
        $progresso.Value = $progresso.Value + 1
    }
    $script:verificado = $true
    Travar $false
    Aplicar-Filtro
    try { $grade.FirstDisplayedScrollingRowIndex = 0 } catch { }
    $total = @($script:instalado.Values | Where-Object { $_ }).Count
    $status.ForeColor = $corNeutra
    $status.Text = "$total programa(s) da lista instalado(s). Marque o que deseja remover e clique em Desinstalar."
}

function Mudar-Aba($NovaAba) {
    if ($script:ocupado -or $NovaAba.Nome -eq $script:abaAtual.Nome) { return }
    $vinhaDeDesinstalar = ($script:abaAtual.Acao -eq 'desinstalar')
    $script:abaAtual = $NovaAba
    Pintar-Abas
    $subtitulo.Text  = $NovaAba.Subtitulo
    $progresso.Value = 0

    if ($NovaAba.Acao -eq 'desinstalar') {
        $btnAcao.Text      = 'Desinstalar'
        $btnAcao.BackColor = $corPerigo
        $btnSugestao.Text  = 'Atualizar'
        foreach ($l in $grade.Rows) { $l.Cells[0].Value = $false }   # por seguranca, nada marcado
        if ($script:verificado) {
            Limpar-Status
            foreach ($l in $grade.Rows) { if ($script:instalado[$l.Tag.id]) { Definir-Status $l 'Instalado' $corSucesso } }
            Aplicar-Filtro
            Atualizar-Contagem
        } else {
            Verificar-Instalados
        }
    } else {
        $btnAcao.Text      = 'Instalar'
        $btnAcao.BackColor = $corDestaque
        $btnSugestao.Text  = 'Recomendados'
        Limpar-Status
        if ($vinhaDeDesinstalar) {
            foreach ($l in $grade.Rows) { $l.Cells[0].Value = $false }
        }
        Aplicar-Filtro
        Atualizar-Contagem
    }
}

foreach ($b in $botoesAba.Values) {
    $b.Add_Click({ param($origem, $e) Mudar-Aba $origem.Tag })
}

# --- Instalar / Desinstalar os marcados da aba atual
$btnAcao.Add_Click({
    $marcadas = Linhas-Marcadas
    $desinstalar = ($script:abaAtual.Acao -eq 'desinstalar')

    if ($marcadas.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Marque pelo menos um programa.', 'KitTec', 'OK', 'Information') | Out-Null
        return
    }
    if ($desinstalar) {
        $nomes = ($marcadas | ForEach-Object { '  - ' + $_.Tag.nome }) -join "`n"
        $resposta = [System.Windows.Forms.MessageBox]::Show(
            "Os programas abaixo serao REMOVIDOS deste computador:`n`n$nomes`n`nDeseja continuar?",
            'Confirmar desinstalacao', 'YesNo', 'Warning')
        if ($resposta -ne 'Yes') { return }
    }

    Travar $true
    $progresso.Maximum = $marcadas.Count
    $progresso.Value   = 0
    $feitos = 0; $pulados = 0; $falhas = 0
    $status.ForeColor = $corNeutra
    $verbo = if ($desinstalar) { 'Desinstalacao' } else { 'Instalacao' }
    Log ("{0} ({1}): {2} programa(s) selecionado(s)" -f $verbo, $script:abaAtual.Nome, $marcadas.Count)

    foreach ($linha in $marcadas) {
        $app = $linha.Tag
        if ($linha.Visible) { try { $grade.FirstDisplayedScrollingRowIndex = $linha.Index } catch { } }
        $status.Text = "Verificando $($app.nome)..."
        Definir-Status $linha 'Verificando...' $corAndamento
        $estaInstalado = Esta-Instalado $app.id

        if (-not $desinstalar -and $estaInstalado) {
            Definir-Status $linha 'Ja instalado' $corNeutra
            Log "$($app.nome): ja instalado"
            $script:instalado[$app.id] = $true
            $pulados++
        } elseif ($desinstalar -and -not $estaInstalado) {
            Definir-Status $linha 'Nao instalado' $corNeutra
            Log "$($app.nome): nao estava instalado"
            $script:instalado[$app.id] = $false
            $pulados++
        } else {
            if ($desinstalar) {
                $status.Text = "Desinstalando $($app.nome)..."
                Definir-Status $linha 'Desinstalando...' $corAndamento
                $codigo  = Desinstalar-App $app.id
                $textoOk = 'Desinstalado'
            } else {
                $status.Text = "Instalando $($app.nome)... isso pode levar alguns minutos."
                Definir-Status $linha 'Instalando...' $corAndamento
                $codigo  = Instalar-App $app.id
                $textoOk = 'Instalado'
            }
            if ($codigo -eq 0) {
                Definir-Status $linha $textoOk $corSucesso
                Log "$($app.nome): $($textoOk.ToLower())"
                $script:instalado[$app.id] = -not $desinstalar
                $feitos++
            } else {
                Definir-Status $linha "Falhou (codigo $codigo)" $corErro
                Log "$($app.nome): FALHOU (codigo $codigo)"
                $falhas++
            }
        }
        $progresso.Value = $progresso.Value + 1
    }

    if ($desinstalar) {
        $resumo = "Concluido: $feitos desinstalado(s), $pulados nao estava(m) instalado(s), $falhas falha(s)."
    } else {
        $resumo = "Concluido: $feitos instalado(s), $pulados ja instalado(s), $falhas falha(s)."
    }
    Log $resumo
    Travar $false
    $status.Text      = "$resumo`nLog: $arquivoLog"
    $status.ForeColor = if ($falhas -gt 0) { $corErro } else { $corSucesso }
    if ($falhas -gt 0) { $script:houveFalha = $true }
})

$form.Add_Shown({
    Pintar-Abas
    $subtitulo.Text = $script:abaAtual.Subtitulo
    Aplicar-Filtro
    $grade.ClearSelection()
    $grade.Focus() | Out-Null   # tira o foco da pesquisa para manter o texto de exemplo
    $status.Text = "{0} programas no total. Marque o que deseja instalar ou use o botao Recomendados." -f $apps.Count
})

[void]$form.ShowDialog()
if ($script:houveFalha) { exit 1 } else { exit 0 }
