# Correção necessária no tempo real do Software Principal

**Destinatário:** desenvolvedor do Software Principal  
**Cliente:** aplicativo móvel Sentinela  
**Data do diagnóstico:** 14/09/2026  
**Prioridade:** bloqueante

## Resumo do problema

O Software Principal detecta pessoas e grava as detecções, mas não permite que
o aplicativo abra o canal WebSocket. A criação do ticket de acesso ao WebSocket
retorna HTTP 500 mesmo quando é utilizado um token de sessão válido.

O aplicativo móvel não consulta o histórico de detecções e não exibe vídeo. A
tela começa vazia depois do login e mostra exclusivamente eventos novos
`detection.created` recebidos pelo WebSocket. Portanto, enquanto o endpoint de
ticket retornar erro, nenhuma pessoa aparecerá no aplicativo.

## Ambiente observado

No teste mais recente, o computador estava em:

```text
IP: 192.168.1.36
Porta ativa da API: 8000
URL base: http://192.168.1.36:8000
serverId: Loja1
apiVersion: 1.0
```

A porta `800` não aceitou conexão. A porta `8000` respondeu normalmente. Caso
a interface do Software Principal exiba `800`, corrigir essa informação para
`8000`.

O IP mudou após a reinicialização do computador. Recomenda-se configurar uma
reserva DHCP no roteador para que esse computador sempre receba o mesmo IPv4.

## Testes realizados

### 1. Servidor e health check: funcionando

```http
GET /api/v1/health
```

Resposta HTTP 200 observada:

```json
{
  "status": "ok",
  "apiVersion": "1.0",
  "serverId": "Loja1",
  "serverTime": "2026-09-14T23:15:47Z",
  "sentinelaEnabled": true
}
```

### 2. Autenticação: funcionando

```http
POST /api/v1/sessions
Content-Type: application/json

{
  "username": "<usuario>",
  "password": "<senha>"
}
```

Com uma credencial válida, o servidor respondeu HTTP 200 com os campos:

```json
{
  "accessToken": "<token>",
  "expiresAt": "<data UTC>",
  "operator": {},
  "server": {}
}
```

### 3. Reconhecimento e gravação: funcionando

A consulta diagnóstica autenticada a `GET /api/v1/detections?limit=5`
retornou detecções recentes com IDs `564` a `568`, status `newPerson` e câmera
`Entrada Principal`. Isso confirma que a câmera e o pipeline de reconhecimento
estavam produzindo registros.

Essa rota foi utilizada somente no diagnóstico. O aplicativo móvel não a
consome.

### 4. Ticket WebSocket: falhando

Requisição com o mesmo token válido:

```http
POST /api/v1/events/ticket
Authorization: Bearer <accessToken>
Accept: application/json
```

Resultado observado:

```http
HTTP/1.1 500 Internal Server Error

Internal Server Error
```

O OpenAPI do servidor não declara body nem parâmetros adicionais para essa
operação. O único parâmetro é o header opcional `Authorization`. Portanto, não
há informação faltando na chamada do aplicativo.

## Comportamento esperado do endpoint de ticket

Com um Bearer token válido, a resposta deve ser HTTP 200:

```json
{
  "ticket": "ticket-opaco-de-uso-unico",
  "expiresAt": "2026-09-14T23:16:30Z"
}
```

Requisitos do ticket:

- gerado com aleatoriedade criptograficamente segura;
- associado à sessão e ao operador autenticado;
- validade máxima de 60 segundos;
- uso único;
- consumido atomicamente pelo handshake WebSocket;
- nunca conter senha nem o access token original.

Depois disso, o cliente abre:

```text
ws://192.168.1.36:8000/api/v1/events?ticket=<ticket>
```

O handler WebSocket deve validar e consumir o ticket, aceitar a conexão e
manter o cliente inscrito nos novos eventos.

## JSON obrigatório para cada nova detecção

Cada detecção produzida depois que o WebSocket estiver conectado deve ser
enviada uma única vez com este envelope:

```json
{
  "schemaVersion": 1,
  "type": "detection.created",
  "eventId": "identificador-unico-do-evento",
  "sequence": 1842,
  "occurredAt": "2026-09-14T23:13:19Z",
  "data": {
    "id": "568",
    "displayCode": "Pessoa #568",
    "status": "newPerson",
    "detectedAt": "2026-09-14T23:13:19Z",
    "camera": {
      "id": "camera-entrada-01",
      "name": "Entrada Principal"
    },
    "photoUrl": "/api/v1/detections/568/photo",
    "occurrenceHistory": []
  }
}
```

Campos que precisam ser respeitados exatamente:

| Campo | Regra |
| --- | --- |
| `schemaVersion` | número inteiro `1` |
| `type` | string exata `detection.created` |
| `eventId` | string única e não vazia |
| `data.id` | string única e não vazia |
| `data.displayCode` | string não vazia |
| `data.status` | `knownThief`, `suspect` ou `newPerson` |
| `data.detectedAt` | data ISO 8601 válida |
| `data.camera.id` | string não vazia |
| `data.camera.name` | string não vazia |
| `data.photoUrl` | string ou `null` |
| `data.occurrenceHistory` | lista, inclusive quando vazia |

Não enviar apenas o objeto `data`: o aplicativo valida o envelope externo,
principalmente `schemaVersion`, `type` e `eventId`. Um frame inválido é ignorado
sem derrubar a conexão.

## Pontos para investigar no servidor

O desenvolvedor deve consultar o traceback produzido no console/log do
processo exatamente no momento do `POST /api/v1/events/ticket`. Verificar:

1. se o armazenamento de tickets é inicializado no startup e compartilhado
   entre a rota HTTP e o handler WebSocket;
2. se a dependência que valida `Authorization: Bearer` é a mesma utilizada nas
   demais rotas v1;
3. se a sessão autenticada possui todos os campos acessados ao criar o ticket;
4. se datas UTC com e sem timezone estão sendo comparadas incorretamente;
5. se o objeto retornado é serializável e usa os nomes `ticket` e `expiresAt`;
6. se a configuração `sentinelaEnabled` realmente inicializa o gerenciador de
   eventos;
7. se uma exceção está sendo ocultada por um handler genérico que devolve
   apenas `Internal Server Error`.

O servidor deveria registrar internamente a exceção e retornar ao cliente um
erro JSON estruturado, sem stack trace ou dados sensíveis.

## Roteiro de validação no Windows PowerShell

Usar uma credencial de teste válida, sem registrar a senha ou o token nos logs:

```powershell
$base = 'http://192.168.1.36:8000'
$body = @{
  username = '<usuario>'
  password = '<senha>'
} | ConvertTo-Json -Compress

$session = Invoke-RestMethod `
  -Uri "$base/api/v1/sessions" `
  -Method Post `
  -ContentType 'application/json' `
  -Body $body

$headers = @{
  Authorization = "Bearer $($session.accessToken)"
  Accept = 'application/json'
}

$ticket = Invoke-RestMethod `
  -Uri "$base/api/v1/events/ticket" `
  -Method Post `
  -Headers $headers

$ticket | Select-Object expiresAt
```

O último comando deve finalizar sem erro e `ticket` deve estar preenchido. Em
seguida, conectar um cliente WebSocket, passar uma pessoa pela câmera e conferir
o recebimento imediato de um único `detection.created`.

## Critérios de aceite

- [ ] A interface mostra a porta realmente ativa (`8000`).
- [ ] `POST /api/v1/events/ticket` retorna HTTP 200 com autenticação válida.
- [ ] Token ausente ou inválido retorna 401, nunca 500.
- [ ] O ticket expira e só pode ser utilizado uma vez.
- [ ] `GET /api/v1/events?ticket=...` realiza o upgrade para WebSocket.
- [ ] Uma nova detecção gera um evento `detection.created` em até dois segundos.
- [ ] O evento contém todos os campos e nomes descritos neste documento.
- [ ] Todos os celulares conectados recebem o evento; os eventos não são
      divididos entre clientes.
- [ ] A geração do evento não depende de consultar o histórico do banco.
- [ ] Nenhuma detecção anterior ao início da sessão é enviada automaticamente.
- [ ] Reiniciar o servidor não altera o endereço divulgado, preferencialmente
      por reserva DHCP ou outra estratégia de endereço estável.

## Observação importante sobre o aplicativo

Não é necessário alterar o aplicativo para ler o banco ou o stream de vídeo.
Quando o endpoint de ticket e o WebSocket estiverem funcionando conforme este
documento, o aplicativo já estará preparado para receber e exibir os eventos em
tempo real.
