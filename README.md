# Sentinela

Aplicativo Flutter para receber, em tempo real, pessoas identificadas pelo
sistema de segurança de uma loja e emitir um alerta prioritário quando uma
pessoa classificada como de alto risco é detectada.

> **Estado atual:** cliente funcional do contrato API v1. A autenticação e as
> fotos usam HTTP/HTTPS; somente novas detecções chegam por WebSocket. Um
> modo simulado continua disponível para desenvolvimento sem servidor.

## Funcionalidades

- formulário de conexão com validação de IPv4, porta, usuário e senha;
- armazenamento seguro do último IP, porta e usuário (a senha nunca é salva);
- listagem apenas das detecções recebidas desde o login atual;
- filtros para pessoas conhecidas, suspeitas e novas;
- detalhes da detecção e histórico de ocorrências;
- recebimento de detecções em tempo real, com reconexão progressiva;
- fila de alertas críticos, com confirmação individual;
- vibração contínua, notificação de alta prioridade e tela de alerta;
- ação explícita para confirmar e parar a vibração na tela e na notificação;
- serviço Android em primeiro plano enquanto o monitoramento está ativo;
- encerramento do monitoramento, da notificação e da vibração ao desconectar.

## Tecnologias

- Flutter e Dart;
- `flutter_bloc` e `equatable` para estado;
- `go_router` para navegação e proteção de rotas;
- `formz` para validação do formulário;
- `flutter_secure_storage` para dados locais não sensíveis da conexão;
- `flutter_local_notifications`, `vibration` e `flutter_foreground_task` para
  alertas nativos;
- `flutter_test`, `bloc_test` e `mocktail` para testes.

As versões exatas estão em [`pubspec.yaml`](pubspec.yaml) e
[`pubspec.lock`](pubspec.lock).

## Pré-requisitos

- Flutter compatível com Dart `>= 3.12.2 < 4.0.0`;
- Android Studio/SDK para executar no Android;
- Xcode e macOS para executar no iOS;
- JDK 17 para compilar o projeto Android.

Confira a instalação com:

```bash
flutter doctor
```

## Executando o projeto

Na raiz do repositório:

```bash
flutter pub get
flutter run
```

Para escolher um dispositivo:

```bash
flutter devices
flutter run -d <id-do-dispositivo>
```

### Conexão com o software principal

Informe o IPv4, a porta e as credenciais configuradas no software principal.
Para a instalação atualmente homologada, o formulário já inicia preenchido
com `192.168.1.20:8000` e o app acessa `http://<ip>:<porta>/api/v1`.

Quando o servidor passar a oferecer TLS, execute ou compile com:

```bash
flutter run --dart-define=API_SCHEME=https
```

HTTP não criptografa credenciais nem dados durante o transporte. A rede local
deve ser isolada e o servidor deve migrar para HTTPS antes do uso definitivo.

### Modo de demonstração

Para executar sem o software principal:

```bash
flutter run --dart-define=USE_MOCKS=true
```

No modo simulado, informe qualquer IPv4 e porta válidos e use:

| Campo | Valor de exemplo |
| --- | --- |
| IP | `192.168.0.10` |
| Porta | `8080` |
| Usuário | `guarda` |
| Senha | `1234` |

Depois da conexão simulada, uma nova detecção crítica é gerada a cada 35
segundos. O alerta só termina após tocar em
**CONFIRMAR E PARAR VIBRAÇÃO**; alertas simultâneos ficam em fila.

## Fluxo principal

1. O app inicializa os canais de notificação suportados pela plataforma.
2. O usuário informa o endereço do sistema principal e suas credenciais.
3. `LoginCubit` valida os campos e autentica pelo `ConnectionRepository`.
4. `SessionCubit` registra a sessão e o roteador abre `/home`.
5. O monitoramento em tempo real começa com a tela vazia.
6. Uma detecção de tipo `knownThief` abre `/alert`, vibra e exibe uma
   notificação nativa.
7. A confirmação marca a detecção apenas no estado local e avança a fila.
8. Ao desconectar, a rota volta ao login e todos os alertas são interrompidos.

## Estrutura do código

```text
lib/
├── main.dart                     # inicialização dos serviços e do app
├── app.dart                      # injeção de dependências e efeitos globais
├── core/
│   ├── storage/                  # armazenamento seguro local
│   ├── theme/                    # tema e cores
│   └── utils/                    # validação do formulário
├── features/
│   ├── auth/                     # login, sessão e conexão
│   ├── detections/               # histórico, modelos, filtros e detalhes
│   └── alert/                    # fila, tela e recursos nativos de alerta
└── routing/                      # rotas e redirecionamento por sessão

test/
├── core/                         # validadores
├── features/                     # cubits de login, detecções e alertas
└── widget_test.dart              # abertura inicial do aplicativo
```

Consulte [Arquitetura](docs/architecture.md) para responsabilidades,
dependências e ciclo dos dados. Os detalhes da implementação estão em
[Integração com o sistema principal](docs/backend-integration.md). A referência
compartilhada com a equipe responsável pelo servidor é o
[Contrato de dados do software principal](docs/software-principal-data-contract.md).

## Plataformas e alertas

| Plataforma | Interface | Vibração/notificação | Segundo plano |
| --- | --- | --- | --- |
| Android | suportada | suportada | foreground service configurado |
| iOS | suportada | implementada, sujeita às permissões/capabilities | limitado pelo iOS sem push remoto |
| Web/Windows/macOS/Linux | útil para conferir a interface | desativada pelo app | não implementado |

No Android, o manifesto solicita vibração, notificações, tela cheia, wake lock
e foreground service. Em Android 13 ou superior, o usuário ainda precisa
autorizar notificações em tempo de execução. Fabricantes podem aplicar regras
adicionais de economia de bateria.

No iOS, notificações com nível crítico exigem configuração e autorização da
Apple além do código já presente. Esse requisito deve ser validado antes de uma
distribuição real.

## Segurança e privacidade

- A senha é usada somente durante a tentativa de conexão e não é persistida.
- IP, porta e usuário podem ser lembrados via armazenamento seguro do sistema.
- O app é de leitura: a confirmação de um alerta não modifica o banco do
  sistema principal.
- As pessoas são exibidas por códigos, não por nomes reais.
- As credenciais de demonstração estão no código e não devem ser usadas em
  produção.
- A futura integração deve autenticar as sessões, validar mensagens e proteger
  o tráfego local (preferencialmente TLS), sem registrar senhas ou dados
  biométricos em logs.

## Qualidade e testes

```bash
flutter analyze
flutter test
```

Também é possível gerar cobertura:

```bash
flutter test --coverage
```

Na última verificação, os testes passaram e o analisador não reportou erros de
compilação ou análise.

## Builds

```bash
# Android
flutter build apk
flutter build appbundle

# iOS (em macOS)
flutter build ios

# Web
flutter build web
```

Antes de distribuir o Android, substitua a assinatura de depuração configurada
em `android/app/build.gradle.kts` por uma chave de produção e revise o
`applicationId`.

## Limitações atuais

- confirmações de alerta não sobrevivem ao encerramento do app;
- a visualização de câmera foi removida temporariamente;
- o monitoramento persistente foi projetado especificamente para Android;
- não há pipeline de integração contínua ou testes de integração nativos.

## Licença

Este repositório ainda não contém um arquivo de licença. Adicione uma licença
antes de permitir uso, modificação ou distribuição por terceiros.
