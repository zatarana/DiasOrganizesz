# Roadmap de reconstrução da aba Finanças

Este roadmap define como a aba **Finanças** foi reconstruída tomando como referência funcional o manual do Minhas Finanças, mas preservando o core do DiasOrganize: tarefas, calendário, projetos, configurações, home, banco local e a aba Dívidas.

A diretriz foi transformar Finanças em um módulo central e completo. Dívidas existe dentro de Finanças como área própria, mas continua aparecendo separadamente na tela inicial como card/resumo rápido.

## Estado atual identificado

- O app já possui `FinancialTransaction` para receitas e despesas.
- O app já possui `Debt` para dívidas.
- Transações já podem se vincular a dívidas por `debtId`.
- Dívidas já podem gerar parcelas financeiras.
- A Home exibe resumo financeiro e resumo de dívidas separadamente.
- Dívidas foi removida como módulo solto de navegação e passou a pertencer à aba Finanças.
- A aba inferior Finanças agora abre uma entrada refinada (`FinanceEntryScreen`) em vez de jogar o usuário diretamente na tela clássica de movimentações.
- A entrada refinada separa uso diário (`FinanceScreen`) de navegação avançada (`FinanceHubScreen`).
- Contas, saldos, transferências, contas ignoradas nos totais e reajustes de saldo já possuem base estrutural.
- Categorias, subcategorias, orçamentos avançados e relatórios financeiros principais já possuem base estrutural, telas e testes.
- Cartões, faturas, compras no cartão, pagamento de fatura e movimentação de compra entre faturas já possuem base estrutural, telas e testes.
- Objetivos financeiros, economia mensal, sugestão de aporte e vínculo futuro com projetos já possuem base estrutural, tela e testes.
- Evolução mensal, débito vs crédito, central de relatórios e exportação CSV já possuem base estrutural, telas e testes.
- A Central Financeira (`FinanceHubScreen`) organiza recursos por visão/planejamento, compromissos/meios de pagamento e análise/exportação.
- Foi criado workflow de CI Flutter para `flutter pub get`, `flutter analyze` e `flutter test`.
- Foi feita correção preventiva de compatibilidade em `FinancialGoal.toMap()` para evitar conflito entre stores antigos e novos.
- Não há ainda anexos, exportação PDF e gráficos visuais com biblioteca dedicada.

## Princípios de implementação

1. Preservar o funcionamento das outras abas.
2. Manter Dívidas dentro da aba Finanças.
3. Manter o card Dívidas na Home como resumo/atalho.
4. Não tratar Dívidas como simples despesa avulsa; dívida precisa ter leitura própria.
5. Toda parcela de dívida deve aparecer em Finanças como despesa vinculada.
6. Toda alteração de parcela deve recalcular a dívida.
7. Toda alteração de dívida deve preservar ou atualizar os vínculos financeiros de forma previsível.
8. Manter o app offline-first.
9. Não incluir sincronização ou segurança neste ciclo.

## Fase 0 — Planejamento e proteção do core

**Objetivo:** documentar o escopo antes de alterações profundas.

### Tarefas

- Criar roadmap da reconstrução financeira.
- Mapear o que já existe no app.
- Definir o que será copiado/adaptado do manual.
- Definir limites para não quebrar Tarefas, Projetos, Calendário, Home e Configurações.

### Critério de conclusão

- Roadmap versionado no repositório.
- Fases claras para implementação.

**Status:** concluída.

## Fase 1 — Finanças passa a enxergar Dívidas

**Objetivo:** fazer Dívidas existir dentro da aba Finanças, mantendo apenas o card separado na Home.

### Tarefas

- Adicionar acesso claro para Dívidas dentro da aba Finanças.
- Criar resumo de dívidas dentro de Finanças.
- Exibir total em aberto, total restante, parcelas a vencer, parcelas atrasadas e abatimentos.
- Criar filtro `Dívidas` na listagem financeira.
- Melhorar busca para encontrar dívida, credor, título, descrição, categoria e observações.
- Marcar visualmente parcelas vinculadas a dívidas.
- Remover Dívidas como módulo solto de `Mais módulos`.
- Remover Dívidas como item independente do menu lateral.
- Manter card Dívidas na Home como resumo/atalho para Finanças.

### Critério de conclusão

- O usuário consegue entender suas dívidas dentro de Finanças.
- A Home continua mostrando Dívidas como resumo separado.
- Dívidas não aparece mais como módulo solto fora de Finanças.
- O pagamento de uma parcela altera o resumo de Finanças e de Dívidas.

**Status:** concluída estruturalmente; pendente validação completa de build.

## Fase 2 — Novo modelo funcional de transações

**Objetivo:** aproximar receitas/despesas do comportamento documentado no manual.

### Tarefas

- Separar data de lançamento, vencimento e efetivação de forma mais clara.
- Melhorar estados: pendente, efetivada/paga, atrasada, cancelada.
- Preparar campos para ignorar em totais, ignorar em estatísticas e ignorar em economia mensal.
- Preparar suporte a tags.
- Preparar suporte a observações avançadas.
- Preparar suporte a anexos no futuro.
- Melhorar recorrência fixa mensal sem duplicar registros.
- Criar regras centralizadas de cálculo financeiro.
- Criar resumo mensal baseado em regras.
- Criar camada de dados da tela de Finanças.
- Criar provider de dados da tela de Finanças.
- Criar testes de regras financeiras.

### Critério de conclusão

- Receitas e despesas terão base de dados pronta para relatórios, gráficos e resumo avançado.
- As regras principais terão testes básicos.

**Status:** concluída estruturalmente; pendente validação completa de build e unificação final com provider novo.

## Fase 3 — Contas, saldos e transferências

**Objetivo:** tornar contas mais parecidas com recipientes reais de dinheiro.

### Tarefas

- Evoluir contas financeiras.
- Adicionar opção de ignorar conta nos totais.
- Criar transferências entre contas.
- Fazer transferências aparecerem como saída na origem e entrada no destino.
- Calcular impacto no saldo geral quando uma conta for ignorada nos totais.
- Adicionar reajuste de saldo.
- Criar histórico básico de reajustes.
- Criar testes de saldo com transações, transferências, reajustes e contas ignoradas.

### Critério de conclusão

- O usuário conseguirá controlar carteira, banco, caixinha, investimento e movimentações entre elas.
- O saldo será recalculável com base em saldo inicial, transações pagas, transferências e reajustes.

**Status:** concluída estruturalmente; pendente validação completa de build.

## Fase 4 — Categorias, subcategorias e orçamentos

**Objetivo:** dar profundidade ao controle financeiro sem complicar demais a UI.

### Tarefas

- Criar subcategorias financeiras.
- Garantir subcategoria padrão `Outros`.
- Melhorar gestão de categorias.
- Criar orçamento por categoria e mês.
- Evoluir orçamento para categoria + subcategoria.
- Mostrar consumo do orçamento na aba Finanças.
- Permitir filtros por categoria e subcategoria.
- Preparar relatórios futuros por categoria/subcategoria.
- Criar relatório de gastos por categoria.
- Criar relatório de gastos por subcategoria.
- Criar comparativo previsto x realizado.
- Criar central de relatórios financeiros.
- Criar testes de store, regras, rankings e relatórios.

### Critério de conclusão

- O usuário conseguirá entender para onde o dinheiro está indo e comparar com limites definidos.
- Orçamentos poderão ser gerais, por categoria ou por subcategoria.
- Relatórios principais estarão isolados em telas próprias e com regras testadas.

**Status:** concluída estruturalmente; pendente validação completa de build.

## Fase 5 — Cartões e faturas

**Objetivo:** criar controle de cartão de crédito sem confundir com dívidas.

### Tarefas

- Criar cadastro de cartões.
- Criar faturas mensais.
- Permitir despesa de cartão vinculada à fatura.
- Permitir mover despesa para próxima fatura.
- Permitir pagamento de fatura a partir de conta.
- Definir quando cartão vira dívida e quando permanece apenas fatura.
- Criar tela inicial de cartões e faturas.
- Criar formulário de compra no cartão.
- Criar testes de store, compras, faturas, pagamentos e movimentação entre faturas.

### Critério de conclusão

- Cartão terá fluxo próprio e não será misturado indevidamente com dívida parcelada.
- Compra de cartão gerará despesa vinculada a fatura.
- Pagamento de fatura afetará uma conta financeira sem virar dívida.
- Compra poderá ser movida para outra fatura.

**Status:** concluída estruturalmente; pendente validação completa de build.

## Fase 6 — Objetivos, economia mensal e planejamento

**Objetivo:** conectar Finanças com planejamento pessoal.

### Tarefas

- Evoluir metas/objetivos financeiros.
- Calcular economia mensal.
- Permitir ignorar transações da economia mensal.
- Mostrar progresso de metas.
- Criar tela inicial de objetivos financeiros.
- Criar atalho reutilizável de objetivos financeiros.
- Preparar integração futura com Projetos quando houver orçamento de projeto.
- Criar testes de store, regras, economia mensal e vínculo com projetos.

### Critério de conclusão

- A aba Finanças mostrará não apenas o que aconteceu, mas também se o usuário está avançando.
- Objetivos financeiros terão fluxo próprio, progresso calculável e sugestão de aporte mensal.
- Objetivos poderão ser vinculados futuramente a projetos sem acoplamento rígido.

**Status:** concluída estruturalmente; pendente validação completa de build.

## Fase 7 — Gráficos, relatórios e exportação

**Objetivo:** permitir análise profunda do histórico financeiro.

### Tarefas

- Criar gráficos simples por categoria/subcategoria usando barras e indicadores nativos.
- Criar evolução mensal de receitas e despesas.
- Criar ranking de gastos.
- Criar visão débito vs crédito.
- Criar relatórios filtráveis.
- Criar exportação CSV de transações e relatórios principais.
- Preparar exportação PDF no futuro.
- Preparar gráficos com biblioteca dedicada no futuro.

### Critério de conclusão

- O usuário conseguirá analisar padrões e não apenas cadastrar lançamentos.
- A Central de Relatórios terá visões reais para evolução mensal, categoria, subcategoria, previsto x realizado, débito vs crédito e exportação CSV.
- A exportação CSV poderá ser gerada e copiada sem depender de permissões de arquivo.

**Status:** concluída estruturalmente; pendente exportação PDF, gráficos com biblioteca dedicada e validação completa de build.

## Fase 8 — Refinamento de UX/UI

**Objetivo:** deixar a aba Finanças simples, rápida e agradável apesar da complexidade.

### Tarefas

- Criar tela de entrada financeira (`FinanceEntryScreen`).
- Criar Central Financeira (`FinanceHubScreen`).
- Separar uso diário de movimentações da navegação avançada.
- Manter a tela clássica de movimentações acessível para lançamentos rápidos.
- Conectar a aba inferior Finanças à nova entrada financeira.
- Conectar cards Financeiro e Dívidas da Home à nova entrada financeira.
- Criar tela com seções bem definidas.
- Melhorar cards de resumo.
- Usar marcadores visuais para fixa, dívida, atraso, ignorada e paga.
- Criar ações rápidas.
- Melhorar formulários compactos e avançados.
- Evitar excesso visual no celular.
- Encaixar de forma definitiva os atalhos estruturais criados nas fases 3 a 7.
- Criar workflow de CI para análise e testes.
- Corrigir compatibilidade de `FinancialGoal` entre stores antigos e novos.

### Critério de conclusão

- A aba será poderosa sem parecer uma planilha jogada dentro do app.
- A navegação principal de Finanças deve abrir uma entrada limpa e compreensível.
- A Home deve preservar card separado de Dívidas, mas direcionar para a experiência financeira integrada.
- O fluxo antigo de movimentações deve continuar acessível.
- As correções estruturais devem ser protegidas por testes quando possível.

**Status:** concluída estruturalmente; pendente validação completa de build em ambiente Flutter/GitHub Actions.

## Progresso geral

| Fase | Nome | Status |
|---|---|---|
| 0 | Planejamento e proteção do core | Concluída |
| 1 | Finanças enxerga Dívidas | Concluída estruturalmente |
| 2 | Novo modelo de transações | Concluída estruturalmente |
| 3 | Contas, saldos e transferências | Concluída estruturalmente |
| 4 | Categorias, subcategorias e orçamentos | Concluída estruturalmente |
| 5 | Cartões e faturas | Concluída estruturalmente |
| 6 | Objetivos e economia mensal | Concluída estruturalmente |
| 7 | Gráficos, relatórios e exportação | Concluída estruturalmente |
| 8 | Refinamento UX/UI | Concluída estruturalmente |

## Observação importante

A reconstrução foi feita em partes pequenas, testáveis e reversíveis. A aba Finanças mudou profundamente, mas o app preserva o funcionamento atual de tarefas, projetos, calendário, dívidas e configurações. A pendência mais importante agora é rodar a validação completa em ambiente Flutter, especialmente `flutter analyze` e `flutter test`, usando o workflow criado.