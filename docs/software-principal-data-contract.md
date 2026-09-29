# Contrato de integração — Software Principal → App Sentinela

> **Revisão de escopo:** o aplicativo não consome mais o histórico REST nem
> exibe vídeo. A lista começa vazia após o login e recebe exclusivamente novos
> eventos `detection.created` pelo WebSocket. As seções de histórico e câmera
> permanecem documentadas apenas como capacidades opcionais do servidor.

**Destinatário:** equipe responsável pelo software principal de segurança  
**Consumidor:** aplicativo Flutter Sentinela  
**Versão do contrato:** 1.0  
**Data:** 13/09/2026

## 1. Objetivo

O software principal deve disponibilizar para o aplicativo móvel:

1. autenticação de um operador;
2. recebimento de novas detecções durante a sessão atual;
3. detalhes e foto de cada detecção;
4. novas detecções em tempo real;
5. identificação imediata de pessoas classificadas como de alto risco.

O aplicativo é, nesta fase, **somente leitura**. A ação “OK, verifiquei” apenas
encerra o alerta no aparelho e não precisa ser enviada ao software principal.

## 2. Transporte escolhido

| Necessidade | Tecnologia | Motivo |
| --- | --- | --- |
| Login, histórico e detalhes | HTTPS + JSON (REST) | requisições pontuais, respostas e erros previsíveis |
| Novas detecções | WebSocket seguro (`wss`) | canal persistente e bidirecional com baixa latência |
| Foto da detecção | HTTPS (`image/jpeg` ou `image/webp`) | evita Base64 e mensagens WebSocket grandes |
| Vídeo ao vivo, se criado no futuro | WebRTC | apropriado para mídia contínua em tempo real |

**WebRTC não é necessário no escopo atual.** Ele adicionaria negociação,
ICE/STUN/TURN e gerenciamento de mídia sem benefício para mensagens JSON e
fotos pontuais. Mesmo que vídeo ao vivo seja adicionado no futuro, os eventos
de detecção devem continuar no WebSocket.

## 3. Topologia esperada

O software principal atua como **servidor** na rede local da loja. O celular
atua como **cliente** e inicia todas as conexões.

```text
Celular (App Sentinela)
    ├── HTTPS ───────► Software principal (login, histórico, detalhes, fotos)
    └── WebSocket ──► Software principal (detecções em tempo real)
```

O operador informa no app o host/IP e a porta exibidos pelo software
principal. Exemplo de endereço base:

```text
https://192.168.0.10:8443
```

Descoberta automática por mDNS/Bonjour pode ser adicionada depois, mas não é
requisito da versão 1.

## 4. Regras gerais do protocolo

- Prefixo da API: `/api/v1`.
- JSON codificado em UTF-8.
- Propriedades JSON em `camelCase`.
- Datas em UTC, no formato RFC 3339/ISO 8601, com sufixo `Z`.
- IDs estáveis, únicos e opacos; UUID é recomendado.
- Os valores de enum são sensíveis a maiúsculas e minúsculas.
- O servidor deve enviar `Content-Type: application/json; charset=utf-8`.
- O servidor não deve enviar nomes reais, documentos ou outros identificadores
  pessoais; o app exibe apenas `displayCode`.
- Campos novos podem ser acrescentados de forma compatível. Campos existentes
  não devem mudar de tipo ou significado dentro da API v1.
- Campos obrigatórios não podem ser omitidos ou enviados como `null`.

## 5. Autenticação

### `POST /api/v1/sessions`

Requisição:

```http
POST /api/v1/sessions HTTP/1.1
Content-Type: application/json

{
  "username": "guarda",
  "password": "senha-do-operador"
}
```

Resposta `200 OK`:

```json
{
  "accessToken": "token-opaco",
  "expiresAt": "2026-09-13T21:00:00Z",
  "operator": {
    "id": "7cb233cf-0056-4a5a-aad8-bad68c6ef496",
    "displayName": "Guarda 1"
  },
  "server": {
    "id": "loja-centro-01",
    "name": "Loja Centro",
    "apiVersion": "1.0"
  }
}
```

O `accessToken` deve ser enviado nas chamadas seguintes:

```http
Authorization: Bearer <accessToken>
```

Requisitos:

- token aleatório ou assinado, com expiração;
- comparação segura de senhas usando hash apropriado no servidor;
- limite de tentativas para reduzir ataques de força bruta;
- nenhuma senha ou token em logs;
- `401 Unauthorized` para credenciais inválidas ou token ausente/inválido;
- `403 Forbidden` para usuário autenticado sem permissão.

Opcionalmente, o servidor pode oferecer `DELETE /api/v1/sessions/current` para
invalidar o token no logout.

## 6. Verificação do servidor

### `GET /api/v1/health`

Endpoint sem autenticação, usado apenas para confirmar compatibilidade e
horário. Não deve expor dados internos.

Resposta `200 OK`:

```json
{
  "status": "ok",
  "apiVersion": "1.0",
  "serverId": "loja-centro-01",
  "serverTime": "2026-09-13T20:15:30Z"
}
```

## 7. Histórico de detecções

### `GET /api/v1/detections?limit=50&cursor=<cursor>`

Parâmetros:

- `limit`: entre 1 e 100; padrão 50;
- `cursor`: opaco e opcional, recebido na página anterior;
- ordenação obrigatória: `detectedAt` decrescente, mais recente primeiro.

Resposta `200 OK`:

```json
{
  "items": [
    {
      "id": "b19725fa-3211-499c-9b07-245a87757771",
      "displayCode": "Pessoa #A231",
      "status": "knownThief",
      "detectedAt": "2026-09-13T20:12:45Z",
      "camera": {
        "id": "camera-entrada-01",
        "name": "Entrada principal"
      },
      "photoUrl": "/api/v1/detections/b19725fa-3211-499c-9b07-245a87757771/photo",
      "occurrenceHistory": [
        {
          "id": "e12d82ca-2eb1-4e7c-b8db-7a3153b77d61",
          "occurredAt": "2026-08-04T15:20:00Z",
          "camera": {
            "id": "camera-caixa-02",
            "name": "Caixa 2"
          },
          "description": "Ocorrência confirmada por revisão de imagens."
        }
      ]
    }
  ],
  "nextCursor": "cursor-opaco-ou-null"
}
```

`nextCursor` deve ser `null` quando não existir outra página.

### Classificações aceitas

| Valor | Significado no app | Dispara alerta crítico |
| --- | --- | --- |
| `knownThief` | pessoa com furto anterior confirmado | sim |
| `suspect` | comportamento/histórico suspeito sem confirmação | não |
| `newPerson` | pessoa sem registro anterior | não |

O software principal é responsável por determinar o status. O app não executa
reconhecimento facial nem recalcula a classificação.

## 8. Modelo obrigatório de detecção

| Campo | Tipo | Obrigatório | Regra |
| --- | --- | --- | --- |
| `id` | string | sim | único e estável |
| `displayCode` | string | sim | código anonimizado para exibição |
| `status` | enum string | sim | um dos três valores documentados |
| `detectedAt` | string datetime | sim | UTC/RFC 3339 |
| `camera.id` | string | sim | identificador estável da câmera |
| `camera.name` | string | sim | nome legível do local |
| `photoUrl` | string ou null | sim | caminho HTTPS relativo ou URL absoluta |
| `occurrenceHistory` | array | sim | vazio quando não houver ocorrências |

Cada ocorrência contém obrigatoriamente:

| Campo | Tipo | Regra |
| --- | --- | --- |
| `id` | string | único e estável |
| `occurredAt` | string datetime | UTC/RFC 3339 |
| `camera.id` | string | identificador da câmera |
| `camera.name` | string | nome legível do local |
| `description` | string | texto curto, sem dados pessoais desnecessários |

## 9. Foto da detecção

### `GET /api/v1/detections/{detectionId}/photo`

- requer o mesmo token Bearer;
- resposta `200 OK` com `Content-Type: image/jpeg` ou `image/webp`;
- resposta `404 Not Found` quando não houver foto;
- tamanho recomendado de até 1 MB;
- resolução recomendada de até 1280 × 1280;
- suporte a `ETag` e `Cache-Control: private` é recomendado.

Não enviar imagem em Base64 no histórico ou no WebSocket. Base64 aumenta o
payload e atrasa justamente o evento que precisa abrir o alerta.

## 10. Detecções em tempo real

### Conexão

```text
wss://<host>:<porta>/api/v1/events
```

Para clientes nativos, o servidor deve aceitar o token no header
`Authorization` durante o handshake. Se também houver suporte ao Flutter Web,
onde headers personalizados no handshake podem ser limitados, o servidor deve
oferecer um ticket WebSocket curto e de uso único:

```http
POST /api/v1/events/ticket
Authorization: Bearer <accessToken>
```

```json
{
  "ticket": "ticket-opaco-de-uso-unico",
  "expiresAt": "2026-09-13T20:16:00Z"
}
```

Conexão correspondente:

```text
wss://<host>:<porta>/api/v1/events?ticket=<ticket>
```

O ticket deve expirar em no máximo 60 segundos e ser invalidado no primeiro
uso. Nunca usar a senha ou um token de longa duração na URL.

### Evento `detection.created`

Cada nova detecção deve ser enviada uma única vez por produção, com este
envelope:

```json
{
  "schemaVersion": 1,
  "type": "detection.created",
  "eventId": "b152cb16-17b5-44fe-b4bc-cf484890c4b3",
  "sequence": 1842,
  "occurredAt": "2026-09-13T20:12:45Z",
  "data": {
    "id": "b19725fa-3211-499c-9b07-245a87757771",
    "displayCode": "Pessoa #A231",
    "status": "knownThief",
    "detectedAt": "2026-09-13T20:12:45Z",
    "camera": {
      "id": "camera-entrada-01",
      "name": "Entrada principal"
    },
    "photoUrl": "/api/v1/detections/b19725fa-3211-499c-9b07-245a87757771/photo",
    "occurrenceHistory": [
      {
        "id": "e12d82ca-2eb1-4e7c-b8db-7a3153b77d61",
        "occurredAt": "2026-08-04T15:20:00Z",
        "camera": {
          "id": "camera-caixa-02",
          "name": "Caixa 2"
        },
        "description": "Ocorrência confirmada por revisão de imagens."
      }
    ]
  }
}
```

Regras do envelope:

- `eventId`: único, usado para deduplicação;
- `sequence`: inteiro crescente por servidor, usado para detectar lacunas;
- `occurredAt`: momento em que o evento foi produzido;
- `data`: o mesmo modelo retornado pela API REST;
- uma retransmissão deve manter o mesmo `eventId` e `sequence`;
- o servidor pode entregar novamente um evento após reconexão; o app deduplica
  por `eventId`/`data.id`.

Todas as classificações devem ser publicadas. O app adiciona todas à lista,
mas abre o alerta crítico somente para `knownThief`.

## 11. Confiabilidade e reconexão

O servidor deve:

- aceitar ping/pong WebSocket e remover conexões inativas;
- manter a ordem dos eventos dentro de uma conexão;
- manter `sequence` monotônico mesmo após clientes reconectarem;
- suportar múltiplos celulares simultaneamente sem dividir os eventos entre
  eles — cada cliente autenticado recebe cada detecção;
- fechar a conexão quando a sessão expirar;
- não bloquear o pipeline de reconhecimento enquanto um celular estiver
  desconectado ou lento.

Ao perder a conexão, o app tentará reconectar com espera progressiva. Depois da
reconexão, ele consultará novamente o histórico REST. Portanto, a versão 1 não
exige replay no WebSocket, mas o histórico deve conter qualquer detecção
ocorrida durante a queda.

Se for implementado replay, pode-se aceitar `?afterSequence=1842`; nesse caso,
o servidor reenvia os eventos posteriores ainda retidos.

## 12. Erros

Erros HTTP usam este formato:

```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Usuário ou senha inválidos.",
    "requestId": "231360bf-4d1d-4fc7-9ca1-67e83d3ead49"
  }
}
```

Status mínimos:

| HTTP | Uso |
| --- | --- |
| `400` | JSON ou parâmetro inválido |
| `401` | credencial/token inválido ou expirado |
| `403` | sem permissão |
| `404` | detecção ou foto inexistente |
| `409` | conflito de estado, quando aplicável |
| `429` | excesso de requisições |
| `500` | erro interno |
| `503` | serviço temporariamente indisponível |

No WebSocket, usar os códigos padrão quando possível. Códigos privados
sugeridos:

| Código | Significado |
| --- | --- |
| `4001` | token/ticket inválido |
| `4002` | sessão expirada |
| `4003` | versão do protocolo não suportada |

## 13. Segurança de transporte

Produção deve usar `https` e `wss`. Mesmo em rede local, tráfego sem TLS pode
ser observado ou alterado por outro dispositivo conectado.

Opções aceitáveis para o certificado do servidor local:

1. certificado emitido por uma autoridade confiável para um hostname que
   resolva localmente; ou
2. autoridade certificadora privada instalada de forma controlada nos
   aparelhos; ou
3. pinning de chave pública/certificado com procedimento documentado de
   rotação e recuperação.

O aplicativo não deve desabilitar globalmente a validação TLS nem aceitar todo
certificado. Para desenvolvimento, HTTP/WS pode ser habilitado apenas em build
de debug e documentado como inseguro.

Outros requisitos:

- escutar apenas nas interfaces de rede necessárias;
- firewall limitado à rede da loja;
- tokens curtos e revogáveis;
- autorização em todos os endpoints de dados e fotos;
- limites de tamanho para JSON, texto e imagens;
- validação estrita de entrada e saída;
- logs de auditoria sem senha, token, foto ou biometria;
- política de retenção e exclusão dos dados definida pela operação da loja.

## 14. Compatibilidade móvel

Para a integração funcionar, o app também precisará ser configurado com:

- Android: permissão `android.permission.INTERNET` e política de segurança de
  rede compatível com o TLS adotado;
- iOS: `NSLocalNetworkUsageDescription` explicando o acesso ao software da
  loja; `NSBonjourServices` somente se mDNS/Bonjour for usado;
- iOS em segundo plano: uma conexão local não garante execução contínua quando
  o sistema suspende o app. Alertas realmente garantidos nessa situação exigem
  uma arquitetura adicional compatível com as regras da Apple.

Essas alterações pertencem ao app, mas dependem da definição final de host,
porta, TLS e descoberta do servidor.

## 15. Quando usar WebRTC

Adicionar WebRTC apenas se surgir o requisito de assistir à câmera em tempo
real no celular. Nesse cenário:

- REST continua responsável por login, histórico e metadados;
- WebSocket continua responsável pelos eventos de detecção e pode transportar
  a sinalização WebRTC;
- WebRTC transporta somente o stream de áudio/vídeo;
- o software principal precisa produzir uma trilha de mídia compatível,
  negociar SDP/ICE e definir STUN/TURN quando a topologia exigir;
- autenticação e autorização devem ocorrer antes de liberar a câmera.

Uma simples foto associada à detecção não justifica WebRTC.

## 16. Critérios de aceite para entrega do servidor

- [ ] `GET /api/v1/health` responde e informa a versão.
- [ ] Login válido retorna token; login inválido retorna `401`.
- [ ] Histórico retorna dados mais recentes primeiro e paginação por cursor.
- [ ] Os três valores de `status` são serializados exatamente como definidos.
- [ ] Datas são UTC e terminam em `Z`.
- [ ] Foto é obtida por HTTPS e exige autenticação.
- [ ] Cada nova detecção chega pelo WebSocket em menos de 2 segundos após ser
      classificada, em condições normais da rede local.
- [ ] Cada cliente conectado recebe todos os eventos.
- [ ] Queda de um cliente não afeta reconhecimento nem outros clientes.
- [ ] Após reconexão, o histórico contém os eventos ocorridos durante a queda.
- [ ] Duplicatas mantêm o mesmo `eventId`; IDs não são reutilizados.
- [ ] Token expirado encerra o WebSocket e bloqueia REST.
- [ ] Nenhuma credencial ou dado biométrico aparece nos logs.
- [ ] TLS e procedimento de instalação/rotação do certificado estão
      documentados.
- [ ] O contrato foi testado com ao menos um aparelho Android físico.

## 17. Entregáveis solicitados ao desenvolvedor do software principal

1. URL base, porta e versão da API.
2. Implementação dos endpoints deste documento.
3. Endpoint WebSocket e método de autenticação escolhido.
4. Certificado/CA e instruções seguras de provisionamento.
5. Arquivo OpenAPI 3.1 dos endpoints REST.
6. JSON Schema dos envelopes WebSocket.
7. Ambiente ou executável de homologação com dados fictícios.
8. Lista documentada de códigos de erro.
9. Instruções de firewall e rede.
10. Contato técnico e procedimento de atualização compatível da API.

## 18. Referências técnicas

- [RFC 6455 — The WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455)
- [W3C WebRTC Recommendation](https://www.w3.org/TR/webrtc/)
- [Android — Cleartext communications](https://developer.android.com/privacy-and-security/risks/cleartext-communications)
- [Apple — NSLocalNetworkUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription)

## 19. Pontos a confirmar entre as equipes

Antes de congelar a versão 1, confirmar:

- hostname/IP e porta padrão;
- método de emissão e instalação do certificado TLS;
- duração do token e necessidade de renovação;
- volume máximo de detecções por hora;
- tamanho/resolução real das fotos;
- período de histórico disponível;
- prazo máximo aceitável entre classificação e alerta;
- número máximo de celulares conectados ao mesmo servidor;
- necessidade futura de enviar a confirmação “OK, verifiquei” ao servidor;
- necessidade futura de vídeo ao vivo.
