# Checklist de atualização segura do APK

Este checklist existe para evitar que usuários percam dados ao atualizar o DiasOrganize.

## Regras obrigatórias antes de gerar APK

1. Não alterar o `applicationId`/package name do Android.
   - O Android usa esse identificador para saber que o APK novo é uma atualização do app já instalado.
   - Se esse valor mudar, o sistema instala outro app e os dados locais ficam separados no app antigo.

2. Usar sempre a mesma assinatura de APK.
   - APKs instalados por cima precisam ter a mesma assinatura.
   - Se a chave mudar, o Android bloqueia a atualização ou exige desinstalação, o que pode apagar dados locais.

3. Sempre aumentar o `versionCode`.
   - No Flutter, isso fica no `pubspec.yaml`, no número depois do `+`.
   - Exemplo: `1.0.0+1` -> `1.0.1+2`.

4. Nunca trocar o nome do banco principal sem migração.
   - O banco atual deve continuar usando o mesmo nome/caminho.
   - Trocar o nome do arquivo cria um banco vazio e faz parecer que os dados sumiram.

5. Nunca usar migração destrutiva em produção.
   - Não apagar tabelas sem migrar os dados.
   - Não usar fallback que recrie o banco automaticamente.
   - Toda mudança de schema deve preservar dados existentes.

6. Testar atualização por cima antes de entregar APK.
   - Instalar uma versão antiga.
   - Criar tarefas, contas, transações, dívidas e projetos.
   - Instalar o APK novo por cima, sem desinstalar.
   - Confirmar que todos os dados continuam lá.

## Procedimento recomendado de teste

1. Instale o APK antigo.
2. Crie dados de teste:
   - uma tarefa;
   - uma conta financeira;
   - uma transação paga vinculada à conta;
   - uma dívida com parcela;
   - um projeto com sessão e tarefa.
3. Gere o APK novo com `versionCode` maior.
4. Instale por cima do APK antigo.
5. Verifique se o app abriu normalmente e se os dados continuam íntegros.

## Observação importante

Se precisar trocar assinatura, package name ou banco, isso deve ser tratado como migração especial e não como atualização comum.
