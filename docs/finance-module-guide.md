# Guia de evolução da aba Finanças

Este documento transforma a referência do manual Minhas Finanças em um guia de implementação para o DiasOrganize.

## Diretriz principal

A aba Finanças deve centralizar receitas, despesas, contas, categorias, orçamentos, metas e dívidas. O módulo Dívidas continua existindo, mas seus valores, parcelas, vencimentos e status precisam aparecer dentro da leitura financeira mensal.

## Integração obrigatória com Dívidas

- Toda dívida pode gerar parcelas como despesas financeiras vinculadas por `debtId`.
- Parcelas pagas devem abater o saldo restante da dívida.
- Descontos em parcelas pagas devem contar como abatimento/economia.
- Parcelas vencidas devem refletir tanto na aba Dívidas quanto na aba Finanças.
- Excluir uma dívida não deve apagar o histórico financeiro automaticamente; o comportamento mais seguro é desvincular ou pedir confirmação específica.

## Estrutura recomendada para Finanças

### Resumo mensal

- Saldo real em contas.
- Resultado realizado do mês.
- Saldo previsto do mês.
- Receitas previstas.
- Despesas previstas.
- Dívidas restantes.
- Parcelas de dívidas a vencer no mês.
- Parcelas de dívidas atrasadas.

### Transações

A listagem deve permitir filtrar por:

- Todas.
- Receitas.
- Despesas.
- Dívidas.
- Pagas/efetivadas.
- Pendentes.
- Atrasadas.
- Categoria.
- Texto livre.

A busca deve considerar título, descrição, observações, categoria, dívida vinculada, credor e método de pagamento.

### Cadastro de movimentação

Campos essenciais:

- Tipo: receita ou despesa.
- Título/descrição.
- Valor.
- Data de lançamento.
- Data de vencimento.
- Data de pagamento/efetivação.
- Categoria financeira.
- Conta vinculada.
- Forma de pagamento.
- Status.
- Recorrência fixa mensal.
- Observações.
- Lembrete local.

Campos a evoluir depois:

- Subcategorias.
- Tags.
- Anexos.
- Ignorar em estatísticas.
- Ignorar em economia mensal.
- Ignorar nos totais.
- Recorrência parcelada/repetida fora de dívidas.
- Transferências entre contas.
- Cartões/faturas.

## O que não deve ser quebrado

- Tarefas não devem depender de Finanças.
- Projetos podem apenas consultar resumo financeiro no futuro, mas não devem ser bloqueados por ele.
- A home pode continuar mostrando cards resumidos, mas o cálculo de dívidas deve continuar vindo de `debtsProvider` e `transactionsProvider`.
- A estrutura offline-first com SQLite local deve ser preservada.

## Prioridade de implementação

1. Mostrar Dívidas dentro da aba Finanças.
2. Melhorar busca e filtros da aba Finanças.
3. Criar cartões de resumo financeiro mais completos.
4. Evoluir cadastro de transações com campos avançados.
5. Criar transferências entre contas.
6. Criar cartões/faturas.
7. Criar relatórios/exportação.
8. Criar gráficos e ranking por categoria.
