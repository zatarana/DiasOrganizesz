# DiasOrganize

Aplicativo de organização pessoal **offline-first** desenvolvido com Flutter, com foco em produtividade, controle financeiro, dívidas e planejamento de projetos em um único app.

---

## Descrição geral

O DiasOrganize foi criado para centralizar o dia a dia pessoal: tarefas, compromissos, finanças, dívidas e projetos, mantendo os dados localmente em SQLite e funcionando mesmo sem internet.

---

## Funcionalidades da versão 1.0

- Gestão de tarefas com prioridades e status.
- Categorias para organização de tarefas.
- Calendário com visão de itens por data.
- Estatísticas básicas de produtividade.
- Tema claro e escuro.
- Lembretes locais.
- Persistência local com SQLite.

---

## Novidades da versão 2.0

- Controle financeiro.
- Receitas e despesas.
- Categorias financeiras.
- Controle de dívidas.
- Parcelas.
- Projetos pessoais.
- Etapas de projetos.
- Vínculo entre projetos e tarefas.
- Dashboard expandido.
- Estatísticas avançadas.
- Calendário integrado.

---

## Módulo de Finanças

- Cadastro de receitas e despesas.
- Status de movimentações (pendente, pago, vencido, cancelado).
- Categorias financeiras (receita/despesa/misto).
- Cálculo de saldo previsto e saldo realizado.
- Controle por mês para visão consolidada.

## Módulo de Dívidas

- Cadastro de dívidas com valor total, credor e observações.
- Geração automática de parcelas no financeiro.
- Acompanhamento de parcelas pagas, pendentes e atrasadas.
- Cálculo de valor restante e progresso de quitação.

## Módulo de Projetos

- Cadastro de projetos com prioridade, cor, ícone e prazo.
- Criação de etapas (steps) por projeto.
- Vínculo de tarefas com projeto/etapa.
- Cálculo de progresso por tarefas ou por etapas.
- Identificação de projetos atrasados e próximos do prazo.

---

## Como rodar localmente

Pré-requisitos:
- Flutter SDK (stable)
- Android SDK (ou emulador/dispositivo Android)

Passos:

```bash
flutter pub get
flutter run
```

---

## Como gerar APK localmente

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK gerado em:

`build/app/outputs/flutter-apk/app-debug.apk`

---

## Como gerar APK pelo GitHub Actions

O workflow já está configurado em `.github/workflows/build-apk.yml` para:

1. Rodar em `push` na `main`.
2. Rodar manualmente com `workflow_dispatch`.
3. Executar `flutter pub get`.
4. Executar `flutter analyze`.
5. Executar `flutter test`.
6. Gerar `flutter build apk --debug`.
7. Publicar artifact.

---

## Como baixar o artifact

1. Acesse a aba **Actions** do repositório no GitHub.
2. Abra o workflow **Build DiasOrganize APK**.
3. Selecione uma execução concluída com sucesso.
4. Na seção **Artifacts**, baixe o arquivo:
   - `DiasOrganize-v2-debug-apk`

---

## Estrutura do projeto

```text
lib/
  app/                # Tema e configurações visuais globais
  core/               # Serviços centrais (ex.: notificações)
  data/
    database/         # SQLite helper, criação e migrações
    models/           # Modelos de domínio
  domain/             # Providers e regras de estado
  features/           # Módulos de UI (tasks, finance, debts, projects, etc.)
test/                 # Testes automatizados
.github/workflows/    # Pipeline CI para validação e build APK
```

---

## Tecnologias usadas

- Flutter
- Dart
- Riverpod
- SQLite (`sqflite`)
- Flutter Local Notifications
- GitHub Actions

---

## Observações sobre banco local

- O app utiliza SQLite local.
- A versão atual do banco foi evoluída com migrações para suportar módulos de finanças, dívidas, projetos e etapas.
- Migrações preservam dados antigos sempre que possível.

## Observações sobre offline-first

- O funcionamento principal não depende de internet.
- Dados são gravados localmente no dispositivo.
- Recursos de organização, acompanhamento e cálculos continuam disponíveis offline.
