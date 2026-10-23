# Segurança — o que está implementado na fase 1

## Palavras-passe
- **Argon2id** (64 MiB, 3 iterações, 2 threads) sobre `HMAC-SHA256(pepper, palavra-passe)`. O *pepper* só existe na configuração do servidor.
- Mínimo 12 caracteres, máximo 128, sem regras artificiais de composição (recomendação NIST). Rejeita palavras-passe comuns, repetitivas ou que contenham o email/nome.
- Verificação contra fugas de dados (Have I Been Pwned, por k-anonymity: só 5 caracteres do hash saem do servidor). Se o serviço falhar, deixa passar.
- Re-hash automático no login se os parâmetros forem reforçados no futuro.

## Sessões
- **Access token**: JWT HS256, 15 minutos, claims `sub`, `role`, `legal_ok`, `jti`. Algoritmo fixado na validação.
- **Refresh token**: 32 bytes aleatórios; só o SHA-256 é guardado. **Rotação** em cada uso. Se um token já rodado for apresentado outra vez, a sessão inteira (família) é revogada. Duração 30 dias, máximo absoluto 90 dias por sessão.
- Terminar sessão num dispositivo (`/auth/logout`) ou em todos (`/me/logout-all`). Mudar ou repor a palavra-passe termina todas as sessões.
- ⚠️ **Para o cliente (Flutter):** serializar os pedidos de `refresh` (um de cada vez). Dois `refresh` em simultâneo com o mesmo token contam como reutilização e terminam a sessão.

## Contra ataques comuns
- **Enumeração de contas:** registo, esquecimento de palavra-passe e reenvio respondem sempre o mesmo; o tempo de resposta é igualado (hash falso quando a conta não existe); contas bloqueadas respondem como credenciais erradas.
- **Força bruta:** 5 falhas bloqueiam a conta 15 minutos (com aviso por email); limites por IP (10/min em login e registo; 5/15 min em operações sensíveis; 300/min geral).
- **Códigos de email:** 6 dígitos, guardados com HMAC, expiram em 15 min, máximo 5 tentativas, um por minuto, só o mais recente é válido.
- **Injeção SQL:** todas as consultas são parametrizadas.
- **Cabeçalhos:** `nosniff`, `X-Frame-Options: DENY`, CSP restritiva, `Cache-Control: no-store`, sem cabeçalho `Server`.
- **Pedidos:** corpo limitado a 64 KB; erros genéricos (sem *stack traces*).
- **Logs:** nunca registam emails, palavras-passe nem tokens. IPs só guardados como HMAC truncado.

## RGPD
- Exportar dados (`GET /me/export`) e eliminar conta (`POST /me/delete`, anonimiza o utilizador e revoga sessões).
- Prova de consentimento versionada e imutável.
- Idade mínima validada no servidor; nada é guardado de quem não a cumpre.

## Em falta (planeado)
- 2FA (TOTP) obrigatório para árbitros e gestores (quando existirem).
- Login Google/Apple (fase 2).
- Rotação de chaves JWT (`kid`) e *refresh* com *grace period* se vier a ser necessário.
- Cópias de segurança cifradas e testadas (produção).
- Revisão de segurança externa antes do lançamento público.
