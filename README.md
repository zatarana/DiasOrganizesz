# DiasOrganize

Aplicativo focado em organização pessoal offline-first feito em Flutter e Dart.

## Como gerar o APK via GitHub Actions

Este repositório conta com integração contínua (CI) usando **GitHub Actions**. O APK é gerado automaticamente a cada push na branch principal (`main`).

1. Envie (Push) este repositório para a sua conta no GitHub.
2. Acesse a aba **Actions** no seu repositório do GitHub.
3. Clique no workflow **Build DiasOrganize APK**.
4. Lá constarão as execuções. Selecione a mais recente com check verde.
5. Role a página da execução selecionada até o fim, na seção **Artifacts**.
6. Conclua o download do arquivo `DiasOrganize-debug-apk` e instale no seu dispositivo Android.

## Como compilar localmente

Para compilar, você precisa ter o Flutter instalado e configurado em seu computador.

1. Baixe este código fonte.
2. Abra o terminal na pasta raiz do projeto.
3. O projeto precisa de algumas configurações nativas do Flutter que não sobem no git para ficar mais limpo. Por isso, gere a base executando:
   ```bash
   flutter create .
   ```
4. Baixe as bibliotecas necessárias:
   ```bash
   flutter pub get
   ```
5. Com um emulador ou dispositivo Android conectado, rode o projeto:
   ```bash
   flutter run
   ```
6. Para gerar um apk manualmente:
   ```bash
   flutter build apk --debug
   ```

## Funcionalidades
- Gerenciamento completo de tarefas offline
- Estatísticas de engajamento
- Calendário de entregas
- Categorias personalizadas
- Tema claro e tema escuro
- Lembretes locais
