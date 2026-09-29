# Diagnóstico do servidor local

Servidor informado: `192.168.1.20:8000`

Diagnóstico realizado em 13/09/2026, a partir de um computador conectado à mesma rede local.

## Resultado

O servidor está ligado e acessível pela rede:

- conexão TCP na porta `8000`: OK;
- `GET http://192.168.1.20:8000/api/v1/health`: HTTP 200;
- API identificada como `FaceTrack 1.4.2`;
- documentação OpenAPI disponível em `/openapi.json` e `/docs`;
- câmera conectada e executando em modo RTSP, conforme `/api/system/camera/status`;
- vídeo disponível como MJPEG em `/api/video_feed`.

Resposta observada no health check:

```json
{
  "status": "ok",
  "apiVersion": "1.0",
  "serverId": "Loja1",
  "serverTime": "2026-09-13T22:58:42Z",
  "sentinelaEnabled": true
}
```

Resposta observada no status da câmera:

```json
{
  "connected": true,
  "running": true,
  "stale": false,
  "mode": "rtsp",
  "last_frame_age_s": 0.0
}
```

## Fluxo esperado no aplicativo

1. O celular e o servidor ficam conectados à mesma rede local.
2. O usuário informa `192.168.1.20`, porta `8000`, usuário e senha.
3. O aplicativo envia `POST /api/v1/sessions` por HTTP.
4. A tela de detecções começa vazia.
5. O aplicativo solicita um ticket em `POST /api/v1/events/ticket` e abre `/api/v1/events` por WebSocket.
6. Somente mensagens novas de tipo `detection.created` são exibidas.
7. As fotos são obtidas pelas URLs contidas nesses eventos.

O aplicativo foi configurado para usar HTTP por padrão nesse endereço. Se o servidor passar a oferecer TLS, deve ser executado com `--dart-define=API_SCHEME=https`.

## Pontos ainda não validados

Em 13/09/2026, uma sessão autenticada foi validada com sucesso: o servidor devolveu `accessToken`, `expiresAt`, `operator` e `server`. A consulta autenticada de detecções também funcionou e retornou `items` e `nextCursor`.

O `POST /api/v1/events/ticket`, entretanto, retornou HTTP 500 (`Internal Server Error`). Portanto, o login funciona, mas nenhuma detecção aparecerá até essa falha ser corrigida no software principal. Por decisão de produto, o aplicativo não consulta o banco como contingência: exibe exclusivamente eventos `detection.created` recebidos ao vivo.

Uma tentativa com credencial propositalmente inválida retornou HTTP 401 no formato abaixo, confirmando que a rota de login recebe corretamente o JSON enviado pelo aplicativo:

```json
{
  "detail": {
    "error": {
      "code": "INVALID_CREDENTIALS",
      "message": "Usuário ou senha de operador inválidos.",
      "requestId": "auth-fail"
    }
  }
}
```

## Atenções de segurança e desempenho

- O servidor atualmente não aceita HTTPS na porta informada. Login, token e dados trafegam sem criptografia; isso deve ficar restrito a uma rede local confiável e o servidor deve receber TLS antes do uso em produção.
- O stream `/api/video_feed` respondeu sem autenticação. Isso permite que qualquer pessoa com acesso à rede e ao endereço veja a câmera; recomenda-se exigir autenticação.
- O stream MJPEG transferiu aproximadamente 38,5 MB em quatro segundos durante o teste. Recomenda-se criar um perfil móvel com resolução, qualidade e taxa de quadros menores.
- Em Flutter Web, o servidor também precisa liberar CORS e uma página hospedada em HTTPS não poderá carregar esse stream HTTP devido a conteúdo misto.
