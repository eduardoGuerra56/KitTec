# KitTec

> **Kit do Técnico.** Instale e remova programas no Windows a partir de uma única tela, sem procurar instaladores na internet.

![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)
![winget](https://img.shields.io/badge/winget-Microsoft-6E4CA5)

## Motivação

**O problema.** No atendimento de campo, preparar um computador costuma significar abrir o navegador, procurar o site de cada fabricante, encontrar o instalador certo, baixar, executar e clicar em "Avançar" várias vezes, programa por programa. Isso consome tempo do técnico, aumenta o risco de baixar instaladores de sites não oficiais e deixa cada máquina configurada de um jeito diferente.

**A solução.** O KitTec reúne tudo em uma janela só. O técnico baixa o projeto, executa o `Instalar.bat` e escolhe na lista o que precisa. A instalação é feita pelo [winget](https://learn.microsoft.com/windows/package-manager/winget/), o gerenciador de pacotes oficial da Microsoft, que baixa a versão mais recente diretamente da fonte oficial e instala sem intervenção. A mesma tela também permite remover programas já instalados.

**Resultado:**

- Menos tempo por atendimento: vários programas instalados em sequência, sem acompanhar cada instalador.
- Mais segurança: nada de instaladores de sites de terceiros.
- Padronização: todas as máquinas recebem os mesmos programas, a partir da mesma lista.
- Rastreabilidade: cada execução gera um log com o que foi instalado, removido ou falhou.

## Como funciona

```
Instalar.bat  ──►  pede permissão de administrador
     │
     ▼
Instalar.ps1  ──►  lê a lista em apps.json
     │             abre a janela de seleção
     │             pula o que já está instalado
     ▼             instala o resto com o winget
 Resumo na janela + log em logs\
```

- **`Instalar.bat`**: o arquivo que o usuário executa. Pede permissão de administrador e chama o script PowerShell.
- **`Instalar.ps1`**: faz o trabalho. Usa o [winget](https://learn.microsoft.com/windows/package-manager/winget/), o gerenciador de pacotes oficial do Windows, que baixa sempre a versão mais recente direto do fabricante.
- **`apps.json`**: a lista de programas. Para adicionar ou remover um app, basta editar esse arquivo, sem mexer no código.

## Como usar

1. Baixe o projeto: no topo desta página, clique em **Code → Download ZIP** e extraia a pasta.
2. Dê dois cliques em **`Instalar.bat`** e aceite a permissão de administrador.
3. Na janela que abrir, escolha a aba, marque os programas e clique em **Instalar**.

### Abas

| Aba | O que tem |
| --- | --- |
| **Instalar** | Programas do dia a dia (navegador, compactador, PDF, acesso remoto...) |
| **Suporte Técnico** | Ferramentas de diagnóstico: CPU-Z, HWiNFO, CrystalDiskInfo, Advanced IP Scanner... |
| **Dev Apps** | Ferramentas de TI e desenvolvimento: VS Code, Git, Windows Terminal, PowerShell 7... |
| **Desinstalar** | Verifica o que está instalado e mostra **só os programas encontrados** para remover |

- **Pesquisa** no canto superior direito: a cada letra digitada, ficam só os programas que começam com o texto (`Esc` limpa a pesquisa).
- **Recomendados / Todos / Nenhum** marcam a lista rapidamente.
- Cada programa mostra o status: *Verificando*, *Instalando*, *Instalado*, *Já instalado* ou *Falhou*.
- Na aba **Desinstalar**, nada vem marcado e há uma confirmação antes de remover. O botão **Atualizar** verifica de novo o que está instalado.

### Sem janela (modo automático)

```bat
Instalar.bat -Padrao                      :: recomendados da aba Instalar
Instalar.bat -Todos                       :: todos da aba Instalar
Instalar.bat -Padrao -Categoria Suporte   :: recomendados da aba Suporte Tecnico
Instalar.bat -Todos -Categoria Tudo       :: todos os programas de todas as abas
```

## Personalizando a lista

Cada programa no `apps.json` tem quatro campos:

```json
{ "nome": "Google Chrome", "id": "Google.Chrome", "categoria": "Geral", "padrao": true }
```

| Campo | O que é |
| --- | --- |
| `nome` | Nome que aparece na lista |
| `id` | Identificador do programa no winget |
| `categoria` | Aba onde aparece: `Geral` (Instalar), `Suporte` ou `Dev` |
| `padrao` | `true` = vem marcado como recomendado |

Para descobrir o `id` de qualquer programa, abra o terminal e pesquise:

```powershell
winget search "nome do programa"
```

Você também pode ter listas diferentes para cada setor, por exemplo `apps-financeiro.json`, e usar:

```powershell
.\Instalar.ps1 -Lista .\apps-financeiro.json
```

## Requisitos

- Windows 10 (1809 ou mais novo) ou Windows 11
- **winget** instalado (já vem no Windows 11; no Windows 10, instale o "Instalador de Aplicativo" pela Microsoft Store)
- Internet e permissão de administrador

> **Erro "winget não encontrado"?** No Windows 10, abra a Microsoft Store, pesquise por **Instalador de Aplicativo** (App Installer), instale ou atualize e execute o `Instalar.bat` novamente.

## Recursos

- Janela com caixas de seleção, status por programa e barra de progresso
- Abas por categoria (**Instalar**, **Suporte Técnico**, **Dev Apps**) e aba **Desinstalar** que mostra só o que está instalado
- Pesquisa instantânea pela inicial do nome
- Execução automática sem janela (`-Padrao` / `-Todos`)
- Detecta e pula programas já instalados
- Instalação silenciosa (sem janelas para clicar "Avançar")
- Resumo final com o status de cada programa
- Log completo de cada execução na pasta `logs`
- Código de saída `1` se algo falhar (útil para automação)

## Autor

**Eduardo Guerra**, Analista de Suporte | Service Desk

[![GitHub](https://img.shields.io/badge/GitHub-eduardoGuerra56-181717?logo=github)](https://github.com/eduardoGuerra56)
