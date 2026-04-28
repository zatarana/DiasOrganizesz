# Roadmap de reconstrução da aba Finanças

Este roadmap define como a aba **Finanças** será reconstruída tomando como referência funcional o manual do Minhas Finanças, mas preservando o core do DiasOrganize: tarefas, calendário, projetos, configurações, home, banco local e a aba Dívidas.

A diretriz é transformar Finanças em um módulo central e completo. Dívidas existe dentro de Finanças como área própria, mas continua aparecendo separadamente na tela inicial como card/resumo rápido.

## Estado atual identificado

- O app já possui `FinancialTransaction` para receitas e despesas.
- O app já possui `Debt` para dívidas.
- Transações já podem se vincular a dívidas por `debtId`.
- Dívidas já podem gerar parcelas financeiras.
- A Home exibe resumo financeiro e resumo de dívidas separadamente.
- Dívidas foi removida como módulo solto de navegação e passou a pertencer à aba Finanças.
- A aba Finanças está em reconstrução gradual para alcançar o escopo desejado.
- Não há ainda transferências completas, cartões/faturas, subcategorias, anexos, relatórios avançados e gráficos financeiros completos.

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

**Status:** concluída estruturalmente; pendente refinamento visual e validação de build.

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

**Status:** em andamento avançado.

## Fase 3 — Contas, saldos e transferências

**Objetivo:** tornar contas mais parecidas com recipientes reais de dinheiro.

### Tarefas

- Evoluir contas financeiras.
- Adicionar opção de ignorar conta nos totais.
- Criar transferências entre contas.
- Fazer transferências aparecerem como saída na origem e entrada no destino.
- Calcular impacto no saldo geral quando uma conta for ignorada nos totais.
- Adicionar reajuste de saldo.

### Critério de conclusão

- O usuário conseguirá controlar carteira, banco, caixinha, investimento e movimentações entre elas.

**Status:** pendente.

## Fase 4 — Categorias, subcategorias e orçamentos

**Objetivo:** dar profundidade ao controle financeiro sem complicar demais a UI.

### Tarefas

- Criar subcategorias financeiras.
- Garantir subcategoria padrão `Outros`.
- Melhorar gestão de categorias.
- Criar orçamento por categoria e mês.
- Mostrar consumo do orçamento na aba Finanças.
- Permitir filtros por categoria e subcategoria.

### Critério de conclusão

- O usuário conseguirá entender para onde o dinheiro está indo e comparar com limites planejados.

**Status:** pendente.

## Fase 5 — Cartões e faturas

**Objetivo:** criar controle de cartão de crédito sem confundir com dívidas.

### Tarefas

- Criar cadastro de cartões.
- Criar faturas mensais.
- Permitir despesa de cartão vinculada à fatura.
- Permitir mover despesa para próxima fatura.
- Permitir pagamento de fatura a partir de conta.
- Definir quando cartão vira dívida e quando permanece apenas fatura.

### Critério de conclusão

- Cartão terá fluxo próprio e não será misturado indevidamente com dívida parcelada.

**Status:** pendente.

## Fase 6 — Objetivos, economia mensal e planejamento

**Objetivo:** conectar Finanças com planejamento pessoal.

### Tarefas

- Evoluir metas/objetivos financeiros.
- Calcular economia mensal.
- Permitir ignorar transações da economia mensal.
- Mostrar progresso de metas.
- Preparar integração futura com Projetos quando houver orçamento de projeto.

### Critério de conclusão

- A aba Finanças mostrará não apenas o que aconteceu, mas também se o usuário está avançando.

**Status:** pendente.

## Fase 7 — Gráficos, relatórios e exportação

**Objetivo:** permitir análise profunda do histórico financeiro.

### Tarefas

- Criar gráficos por categoria.
- Criar evolução mensal de receitas e despesas.
- Criar ranking de gastos.
- Criar visão débito vs crédito.
- Criar relatórios filtráveis.
- Preparar exportação CSV/PDF no futuro.

### Critério de conclusão

- O usuário conseguirá analisar padrões e não apenas cadastrar lançamentos.

**Status:** pendente.

## Fase 8 — Refinamento de UX/UI

**Objetivo:** deixar a aba Finanças simples, rápida e agradável apesar da complexidade.

### Tarefas

- Criar tela com abas internas ou seções bem definidas.
- Melhorar cards de resumo.
- Usar marcadores visuais para fixa, dívida, atraso, ignorada e paga.
- Criar ações rápidas.
- Melhorar formulários compactos e avançados.
- Evitar excesso visual no celular.

### Critério de conclusão

- A aba será poderosa sem parecer uma planilha jogada dentro do app.

**Status:** pendente.

## Progresso geral

| Fase | Nome | Status |
|---|---|---|
| 0 | Planejamento e proteção do core | Concluída |
| 1 | Finanças enxerga Dívidas | Concluída estruturalmente |
| 2 | Novo modelo de transações | Em andamento avançado |
| 3 | Contas, saldos e transferências | Pendente |
| 4 | Categorias, subcategorias e orçamentos | Pendente |
| 5 | Cartões e faturas | Pendente |
| 6 | Objetivos e economia mensal | Pendente |
| 7 | Gráficos, relatórios e exportação | Pendente |
| 8 | Refinamento UX/UI | Pendente |

## Observação importante

A reconstrução deve ser feita em partes pequenas, testáveis e reversíveis. A aba Finanças mudará profundamente, mas o app não deve perder o funcionamento atual de tarefas, projetos, calendário, dívidas e configurações.
