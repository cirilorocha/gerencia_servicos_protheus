# Gerenciador de Serviços TOTVS / Fluig

Um script em PowerShell para facilitar o gerenciamento de múltiplos serviços relacionados ao ambiente TOTVS Protheus e Fluig no Windows.

Em ambientes de desenvolvimento, homologação ou até mesmo em servidores com várias instâncias do Protheus, é comum precisar parar, iniciar ou reiniciar diversos serviços. Quando existem poucas instâncias, realizar esse processo manualmente é simples. Porém, quando temos 10, 20 ou mais serviços, executar cada operação individualmente se torna trabalhoso e aumenta a possibilidade de erros na ordem de execução.

Este script foi criado justamente para simplificar esse processo.

## O que o script faz?

O **Gerenciador de Serviços TOTVS / Fluig** permite identificar os serviços relacionados ao ambiente, selecionar quais serão manipulados e executar as operações de forma organizada, respeitando uma ordem de prioridade.

Por meio de uma interface de seleção baseada no `Out-GridView`, é possível escolher os serviços que serão afetados sem precisar executar cada comando manualmente.

As principais operações disponíveis são:

* **Parar serviços**
* **Iniciar serviços**
* **Reiniciar serviços**
* **Subir novamente os últimos serviços que foram parados**
* **Visualizar o arquivo de log**

## Ordem de execução

Um dos principais objetivos do script é respeitar a dependência entre os serviços.

Para isso, os serviços são classificados automaticamente em níveis de prioridade:

| Prioridade | Tipo de serviço |
| ---------- | --------------- |
| 1          | License         |
| 2          | DBAccess        |
| 3          | Indexer / Solr  |
| 4          | Realtime        |
| 5          | Demais serviços |

A lógica é invertida de acordo com a operação:

**Ao parar:**

`Aplicações → Realtime → Indexer/Solr → DBAccess → License`

**Ao iniciar:**

`License → DBAccess → Indexer/Solr → Realtime → Aplicações`

Dessa forma, o script procura seguir uma sequência mais adequada para a parada e inicialização do ambiente.

A identificação da prioridade é feita com base no nome, nome de exibição e descrição do serviço. Essa lógica também pode ser ajustada conforme as características de cada ambiente.

## Seleção dos serviços

O script identifica automaticamente serviços relacionados a termos como:

* TOTVS
* TSS
* DBAccess
* DBACES
* License
* Fluig
* Solr

Os serviços identificados são apresentados para seleção através do `Out-GridView`.

Isso permite selecionar apenas as instâncias que realmente precisam ser manipuladas.

## Reinicialização

A opção **Reiniciar serviços** executa um ciclo completo:

1. Seleciona os serviços atualmente em execução.
2. Realiza a parada respeitando a ordem de prioridade.
3. Aguarda a conclusão da etapa de parada.
4. Inicia novamente os mesmos serviços.
5. Executa a inicialização respeitando a ordem inversa de prioridade.

Isso evita a necessidade de selecionar novamente os serviços entre a parada e a inicialização.

## Recuperação dos últimos serviços parados

Uma funcionalidade criada especificamente para facilitar o trabalho durante manutenção é a opção:

**"SUBIR últimos serviços que foram parados"**

Quando o usuário realiza uma parada através do script, os serviços selecionados são armazenados em memória durante a execução do script.

Assim, após realizar alguma atividade de manutenção, configuração ou teste, basta selecionar essa opção para iniciar novamente os mesmos serviços que foram parados anteriormente.

> O histórico é mantido apenas durante a execução atual do script. Ao fechar o script, essa informação é perdida.

## Logs

Todas as operações executadas são registradas em um arquivo de log:

`Log_Servicos_Totvs_Fluig.txt`

O log registra informações como:

* Data e hora da operação
* Serviço manipulado
* Descrição do serviço
* PID do processo, quando disponível
* Operação realizada
* Prioridade atribuída ao serviço
* Eventos de parada forçada

Isso facilita a análise do que foi executado durante uma manutenção ou procedimento de reinicialização.

## Parada forçada

Durante a parada de um serviço, o script aguarda até 30 segundos para que o serviço seja encerrado normalmente.

Caso o serviço não seja finalizado nesse período e exista um PID associado, o script tenta realizar a finalização forçada do processo.

Essa funcionalidade deve ser utilizada com atenção, principalmente em ambientes de produção.

## Requisitos

* Windows
* PowerShell
* Permissão de Administrador
* `Out-GridView` disponível no ambiente

O script precisa ser executado com privilégios administrativos, pois as operações de parada e inicialização de serviços do Windows normalmente exigem essa permissão.

Caso não seja executado como administrador, o script identifica a situação e solicita que o PowerShell seja executado com privilégios elevados.

## Utilização

Execute o script pelo PowerShell como Administrador:

```powershell
.\Gerenciador Serviços Totvs.ps1
```

Será apresentado o menu principal:

```text
=== GERENCIADOR TOTVS/FLUIG ===

1. PARAR serviços
2. INICIAR serviços
3. REINICIAR serviços
4. SUBIR últimos serviços que foram parados
5. Abrir arquivo de Log
6. Sair
```

Após escolher uma operação, os serviços disponíveis serão apresentados para seleção.

## Atenção

Este script foi desenvolvido para facilitar operações administrativas em ambientes TOTVS e Fluig, principalmente durante atividades de desenvolvimento, testes, homologação e manutenção.

Antes de utilizar em produção, recomenda-se validar a classificação de prioridade dos serviços e os nomes utilizados no ambiente, pois cada instalação pode possuir serviços, dependências e configurações diferentes.

A opção de parada forçada também deve ser utilizada com cautela.

## Personalização

A identificação dos serviços e a hierarquia de prioridades podem ser adaptadas conforme o ambiente.

A função responsável pela definição da prioridade é:

```powershell
Get-Priority
```

Já a função responsável pela identificação dos serviços alvo é:

```powershell
Obter-ServicosAlvo
```

Essas duas funções são os principais pontos para personalização do script.

## Objetivo do projeto

A ideia deste projeto é simples: **reduzir o trabalho manual e tornar mais seguro e previsível o gerenciamento de múltiplos serviços TOTVS e Fluig**.

Se você trabalha frequentemente com ambientes Protheus contendo várias instâncias de AppServer, DBAccess, License, TSS, Fluig, Solr ou outros serviços relacionados, este script pode tornar as rotinas de parada e inicialização muito mais rápidas e organizadas.
