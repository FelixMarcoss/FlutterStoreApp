# Integração com o sistema principal

Este documento descreve a implementação interna usada para comunicar com o
computador da loja. O contrato implementado pelo servidor, incluindo endpoints
e formatos definitivos,
está em [Contrato de dados do software principal](software-principal-data-contract.md).

## Pontos de substituição

O app contém implementações concretas de:

- `ConnectionRepository`, para autenticação e encerramento da sessão;
- `DetectionRepository`, para eventos em tempo real e fotos relacionadas.

Em produção, `lib/app.dart` instancia:

```dart
_connectionRepository = RemoteConnectionRepository(session: session);
_detectionRepository = RemoteDetectionRepository(session: session);
```

Os Cubits e as telas dependem das interfaces e não conhecem HTTP ou WebSocket.
Os mocks podem ser ativados com `--dart-define=USE_MOCKS=true`.

## Mapeamento do contrato para o app

- `POST /api/v1/sessions` será chamado por `ConnectionRepository.connect`;
- `GET /api/v1/detections` não é consumido pelo aplicativo;
- `GET /api/v1/detections/{id}/photo` fornecerá os bytes opcionais da foto;
- `wss://<host>:<porta>/api/v1/events` alimentará `alertsStream`;
- `/api/video_feed` não é consumido pelo aplicativo;
- `camera.name` será convertido para `Detection.cameraLocation`;
- `occurrenceHistory[].occurredAt` será convertido para `Occurrence.date`;
- `occurrenceHistory[].camera.name` será convertido para
  `Occurrence.cameraLocation`.

O repositório deve decodificar `data` dos eventos `detection.created` e
publicar a detecção em `alertsStream`. Apesar do nome histórico da propriedade,
ela recebe todas as classificações: o `DetectionsCubit` atualiza a listagem e o
`AlertCubit` filtra somente `knownThief`.

A lista começa vazia em cada login. O aplicativo não recupera registros
anteriores nem repõe eventos perdidos durante uma desconexão.

O token deve permanecer em memória, salvo se houver uma política explícita e
segura de renovação. Erros conhecidos de conexão/autenticação devem virar
`ConnectionException` com mensagem adequada ao usuário.

## Lifecycle esperado

1. `connect` autentica e guarda o token em memória.
2. Após `SessionCubit` receber a conexão, `startRealtime` abre o WebSocket.
3. `fetchHistory` busca os registros atuais.
4. Quedas transitórias tentam reconectar com backoff e limite configurável.
5. `stopRealtime` fecha socket, timers e tentativas de reconexão.
6. `disconnect` invalida a sessão no servidor, quando suportado, e apaga o
   token em memória.
7. `dispose` encerra permanentemente controllers e clientes.

`startRealtime` e `stopRealtime` devem ser idempotentes. Eventos de uma conexão
antiga não podem vazar para uma sessão nova.

## Execução em segundo plano

No Android, a conexão persistente deve viver no `TaskHandler` registrado por
`sentinelaForegroundTaskCallback`, não apenas no isolate da interface. Será
necessário encaminhar eventos entre o isolate do serviço e o app e definir a
estratégia para quando a interface não estiver ativa.

No iOS, uma conexão WebSocket local não tem execução indefinida em segundo
plano. Para alertas confiáveis com o app suspenso, será preciso rever a
arquitetura — por exemplo, usar notificações push por uma infraestrutura
permitida — e validar as restrições operacionais e de privacidade.

## Configuração das plataformas

A integração real exigirá revisar arquivos nativos:

- Android: adicionar `android.permission.INTERNET`; se HTTP/WS sem TLS for
  inevitável na rede local, definir uma política explícita de tráfego em texto
  claro, limitada aos destinos necessários;
- iOS: adicionar a descrição de acesso à rede local e, se houver descoberta de
  serviço, declarar os tipos Bonjour; exceções ATS devem ser específicas e
  justificadas; alertas com `InterruptionLevel.critical` também exigem a
  capability/entitlement concedida pela Apple;
- produção: configurar assinatura, identificadores exclusivos e ícones/nome
  definitivos.

Não adicione exceções globais de TLS nem aceite qualquer certificado. Em uma
rede local controlada, prefira TLS com uma cadeia confiável ou pinning que
tenha estratégia documentada de rotação.

## Validação dos dados

A camada de dados deve rejeitar ou tratar com segurança:

- status desconhecidos;
- datas inválidas ou sem fuso horário;
- IDs vazios ou duplicados;
- imagens excessivamente grandes ou com formato/tipo de conteúdo inválido;
- mensagens incompletas;
- frames WebSocket inesperados;
- respostas de uma sessão expirada.

Defina limites para payloads e histórico. Nunca registre senha, token, foto ou
outros dados pessoais em logs de produção.

## Critérios mínimos para concluir a integração

- autenticação real e logout testados;
- histórico convertido para os modelos de domínio;
- WebSocket com reconexão e encerramento previsíveis;
- erros traduzidos para estados compreensíveis na interface;
- permissões e políticas de rede configuradas em Android e iOS;
- testes unitários dos parsers e repositórios;
- teste de integração contra um servidor de homologação;
- revisão de segurança, privacidade e retenção de dados;
- teste em aparelho físico com app em primeiro plano, segundo plano e tela
  bloqueada.
