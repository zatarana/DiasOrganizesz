# Roadmap de reconstrução da aba Tarefas

Este roadmap define a evolução da aba **Tarefas** com base em um modelo avançado de produtividade pessoal, preservando o core do DiasOrganize: Home, Calendário, Projetos, Estatísticas, Categorias, notificações locais e armazenamento offline.

## Premissas

- Tarefas continuam sendo o núcleo do app.
- A Home continua exibindo tarefas de hoje, pendentes e atrasadas.
- A aba Calendário continua lendo tarefas por data.
- Projetos continuam usando tarefas e sessões para cálculo de progresso.
- Categorias atuais continuam utilizáveis.
- Subtarefas continuam vinculadas por `parentTaskId`.
- Lembretes locais continuam dependentes de data e hora.
- Nada de sincronização, autenticação, colaboração online ou segurança neste ciclo.

## Etapas de implementação

### Fase 0 — Diagnóstico e proteção do core

- Mapear modelo atual `Task`.
- Mapear tela atual de lista de tarefas.
- Mapear tela atual de criação/edição de tarefas.
- Mapear uso de tarefas na Home.
- Mapear uso de tarefas no Calendário.
- Mapear uso de tarefas em Projetos.
- Mapear uso de tarefas em Estatísticas.
- Mapear uso de categorias em tarefas.
- Mapear notificações locais de tarefas.
- Mapear subtarefas existentes.
- Registrar correlações obrigatórias.
- Criar issue da reconstrução.
- Criar roadmap versionado.

### Fase 1 — Regras centrais de classificação

- Criar regras de data de tarefa.
- Criar regra de tarefa atrasada.
- Criar regra de tarefa de hoje.
- Criar regra de tarefa dos próximos 7 dias.
- Criar regra de tarefa sem data.
- Criar regra de tarefa de Inbox.
- Criar regra de tarefa ativa.
- Criar regra de tarefa concluída.
- Criar regra de tarefa cancelada.
- Criar regra de tarefa pai.
- Criar regra de subtarefa.
- Criar agrupamento de subtarefas por tarefa pai.
- Criar cálculo de progresso do dia.
- Criar cálculo de tarefas sugeridas.
- Criar cálculo de tarefas pendentes antigas.
- Criar ordenação por data.
- Criar ordenação por hora.
- Criar ordenação por prioridade.
- Criar ordenação manual futura.
- Criar testes das regras centrais.

### Fase 2 — Entrada Tarefas / Central de produtividade

- Criar tela de entrada de tarefas.
- Separar uso diário de exploração avançada.
- Adicionar card Hoje.
- Adicionar card Inbox.
- Adicionar card Todas as tarefas.
- Adicionar card Próximos 7 dias.
- Adicionar card Sem data.
- Adicionar card Atrasadas.
- Adicionar card Calendário.
- Adicionar card Projetos vinculados.
- Adicionar card Estatísticas.
- Preservar tela clássica de lista.
- Criar atalho reutilizável da entrada de tarefas.
- Conectar aba inferior Tarefas à nova entrada.
- Manter FAB de criação rápida.

### Fase 3 — Today / Hoje

- Criar tela Hoje.
- Criar cabeçalho com data atual.
- Exibir percentual de conclusão do dia.
- Exibir tarefas atrasadas sugeridas.
- Exibir tarefas do dia em ordem cronológica.
- Exibir tarefas sem data como sugestão de agendamento.
- Exibir subtarefas no contexto da tarefa pai.
- Exibir badge de atraso.
- Exibir prioridade visual.
- Exibir lista/categoria de origem.
- Exibir vínculo com projeto quando existir.
- Permitir concluir tarefa rapidamente.
- Permitir reabrir tarefa concluída.
- Permitir abrir detalhes da tarefa.
- Permitir adiar tarefa para amanhã.
- Permitir mover tarefa para sem data.
- Permitir criar tarefa já no dia atual.
- Preservar atualização da Home.
- Preservar atualização do Calendário.
- Preservar atualização de Projetos.

### Fase 4 — Inbox / Caixa de entrada

- Definir tarefa de Inbox como tarefa sem lista/projeto/categoria obrigatória ou com marcador de captura.
- Permitir criar tarefa sem data.
- Permitir criar tarefa sem categoria rígida.
- Permitir capturar título rapidamente.
- Permitir processar Inbox.
- Permitir mover para categoria.
- Permitir vincular a projeto.
- Permitir definir data.
- Permitir definir prioridade.
- Permitir concluir ou cancelar em lote futuramente.
- Criar tela Inbox.
- Criar contador de Inbox.
- Conectar Inbox à entrada de tarefas.
- Garantir que Inbox não quebre categorias antigas.

### Fase 5 — Quick Add

- Criar componente Quick Add.
- Campo único para título.
- Captura rápida a partir da Home.
- Captura rápida a partir de Tarefas.
- Captura rápida a partir do Calendário com data herdada.
- Captura rápida a partir de Projetos com projeto herdado.
- Sintaxe simples para prioridade.
- Sintaxe simples para data: hoje, amanhã, próxima semana.
- Sintaxe simples para hora.
- Sintaxe simples para tag futura.
- Salvar no Inbox quando não houver contexto.
- Salvar no dia selecionado quando houver contexto.
- Salvar no projeto selecionado quando houver contexto.
- Testar parsing básico.

### Fase 6 — Listas, categorias e pastas internas

- Manter categorias atuais como organização inicial.
- Criar conceito futuro de lista de tarefa sem quebrar categoria.
- Mapear categoria atual para lista visual.
- Permitir cor/ícone herdados da categoria.
- Preparar campo de seção futura.
- Preparar campo de ordem manual futura.
- Preparar agrupamento por categoria/lista.
- Criar tela de listas de tarefas.
- Criar contagem por lista.
- Preservar vínculos com projetos.
- Preservar filtros por categoria.

### Fase 7 — Detalhes avançados da tarefa

- Melhorar painel/formulário de detalhes.
- Título inline.
- Descrição longa.
- Data.
- Hora.
- Lembrete.
- Recorrência.
- Prioridade com quatro níveis futuros.
- Categoria/lista.
- Projeto.
- Sessão de projeto.
- Subtarefas.
- Notas.
- Tags futuras.
- Estimativa de duração futura.
- Status.
- Exclusão.
- Cancelamento.
- Reabertura.
- Validações de lembrete.
- Validações de projeto arquivado/concluído.

### Fase 8 — Smart Lists

- Criar tela Próximos 7 Dias.
- Criar tela Todas as tarefas.
- Criar tela Atrasadas.
- Criar tela Sem data.
- Criar tela Concluídas recentes.
- Criar tela Alta prioridade.
- Criar estrutura de filtros salvos futura.
- Criar regras de combinação por data/status/prioridade/categoria/projeto.
- Conectar à entrada de tarefas.
- Preservar tela clássica.

### Fase 9 — Busca e filtros avançados

- Busca por título.
- Busca por descrição.
- Busca por prioridade.
- Busca por status.
- Busca por data.
- Busca por categoria.
- Busca por projeto.
- Busca por subtarefa.
- Busca por recorrência.
- Histórico de busca futuro.
- Filtros combinados.
- Chips de filtro.
- Ordenação por data.
- Ordenação por prioridade.
- Ordenação por status.

### Fase 10 — Calendário integrado

- Garantir criação de tarefa a partir de dia selecionado.
- Garantir conclusão inline no calendário.
- Garantir remarcação de data.
- Preparar visão agenda.
- Preparar visão próximos dias.
- Exibir tarefas recorrentes.
- Exibir tarefas concluídas opcionalmente.
- Exibir tarefas sem data fora do calendário.
- Preservar tela atual de calendário.

### Fase 11 — Kanban

- Criar modelo de seção futura.
- Criar agrupamento visual por status/categoria/projeto.
- Criar tela Kanban inicial.
- Coluna pendentes.
- Coluna em andamento futura.
- Coluna concluídas.
- Cards com prioridade/data/projeto.
- Abrir detalhes ao tocar.
- Preparar drag-and-drop futuro.
- Preservar lista linear.

### Fase 12 — Matriz de prioridade

- Criar tela Matriz.
- Mapear prioridade alta para fazer agora.
- Mapear prioridade média para agendar.
- Mapear prioridade baixa para delegar/baixa urgência.
- Mapear sem prioridade futura para eliminar/baixa importância.
- Permitir filtro por categoria.
- Permitir filtro por projeto.
- Abrir tarefa ao tocar.
- Atualizar quadrante ao mudar prioridade.

### Fase 13 — Foco e duração

- Preparar campo de duração estimada futuro.
- Criar regra de tarefas com foco acumulado futura.
- Criar tela de foco futura.
- Vincular sessão de foco a tarefa futura.
- Exibir foco em estatísticas futuras.
- Não implementar bloqueio estrito neste ciclo.

### Fase 14 — Hábitos e rotinas

- Separar hábito de tarefa comum.
- Preparar módulo de hábitos futuro.
- Permitir exibir hábitos no Hoje futuramente.
- Permitir estatísticas de consistência futuramente.
- Não misturar hábitos com subtarefas.

### Fase 15 — Estatísticas de tarefas

- Total criadas.
- Total concluídas.
- Total atrasadas.
- Taxa de conclusão diária.
- Taxa de conclusão semanal.
- Distribuição por prioridade.
- Distribuição por categoria.
- Distribuição por projeto.
- Dia mais produtivo.
- Histórico mensal.
- Conectar à aba Estatísticas existente.

### Fase 16 — Configurações de tarefas

- Aba padrão ao abrir tarefas.
- Ação padrão de swipe futura.
- Hora padrão de lembrete.
- Dia inicial da semana.
- Exibir ou ocultar concluídas.
- Ordenação padrão.
- Categoria padrão.
- Inbox como padrão.
- Mostrar projetos nos cards.
- Mostrar subtarefas inline.

### Fase 17 — Widgets e atalhos futuros

- Preparar widget Today futuro.
- Preparar widget Quick Add futuro.
- Preparar widget lista futura.
- Preparar deep links futuros.
- Não implementar widget nativo neste ciclo sem validação Android.

### Fase 18 — Refinamento UX/UI

- Reduzir densidade visual.
- Criar cards claros.
- Criar badges de prioridade.
- Criar badges de atraso.
- Criar badges de projeto.
- Criar empty states.
- Criar mensagens de celebração.
- Melhorar fluxo mobile.
- Garantir acessibilidade básica.
- Garantir textos curtos.

### Fase 19 — Validação

- Rodar `flutter analyze`.
- Rodar `flutter test`.
- Corrigir falhas de testes.
- Validar Home.
- Validar Tarefas.
- Validar Calendário.
- Validar Projetos.
- Validar Estatísticas.
- Validar notificações locais.
- Validar build APK.

## Progresso

| Fase | Nome | Status |
|---|---|---|
| 0 | Diagnóstico e proteção do core | Iniciada |
| 1 | Regras centrais de classificação | Próxima |
| 2 | Entrada Tarefas / Central de produtividade | Pendente |
| 3 | Today / Hoje | Pendente |
| 4 | Inbox / Caixa de entrada | Pendente |
| 5 | Quick Add | Pendente |
| 6 | Listas, categorias e pastas internas | Pendente |
| 7 | Detalhes avançados da tarefa | Pendente |
| 8 | Smart Lists | Pendente |
| 9 | Busca e filtros avançados | Pendente |
| 10 | Calendário integrado | Pendente |
| 11 | Kanban | Pendente |
| 12 | Matriz de prioridade | Pendente |
| 13 | Foco e duração | Pendente |
| 14 | Hábitos e rotinas | Pendente |
| 15 | Estatísticas de tarefas | Pendente |
| 16 | Configurações de tarefas | Pendente |
| 17 | Widgets e atalhos futuros | Pendente |
| 18 | Refinamento UX/UI | Pendente |
| 19 | Validação | Pendente |
