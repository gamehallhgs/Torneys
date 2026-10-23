# Lista de verificação antes do lançamento

Esta lista não substitui aconselhamento jurídico. Marca cada ponto antes de publicar nas lojas.

## Legal e privacidade
- [ ] Preencher todos os `[PREENCHER ...]` em `backend/src/GameHall.Api/Legal/*.md` (a API recusa arrancar em produção sem isto).
- [ ] Revisão por advogado/especialista em RGPD: Termos, Política de Privacidade e tratamento de menores (13–17 anos).
- [ ] Definir prazos de retenção (registos de consentimento e segurança).
- [ ] Contratos de tratamento de dados (DPA) com o fornecedor de alojamento, de email e Firebase.
- [ ] Registo das atividades de tratamento (documento interno exigido pelo RGPD).
- [ ] Processo para responder a pedidos de titulares (acesso, apagamento) e para notificar violações de dados (72 h).
- [ ] Consentimento específico de imagem para vídeos/highlights (fase 5) e autorização de encarregado de educação para menores, se aplicável.
- [ ] Se passares a ter atividade comercial (pagamentos): atividade nas Finanças, Livro de Reclamações Eletrónico, termos de pagamento e reembolso.

## App Store (Apple)
- [ ] Conta Apple Developer (99 USD/ano).
- [ ] "Sign in with Apple" disponível (obrigatório se houver login Google).
- [ ] Eliminar conta dentro da app (já existe no backend: `POST /me/delete`; falta o ecrã na fase 2).
- [ ] URL público da Política de Privacidade e URL de suporte.
- [ ] Etiquetas de privacidade ("Privacy Nutrition Labels") preenchidas.
- [ ] Questionário de classificação etária (a app é 13+).
- [ ] Conta de demonstração para a revisão da Apple.
- [ ] Conteúdo gerado por utilizadores (nomes de equipa): denunciar, bloquear, moderação e contacto.
- [ ] Pedido claro de permissão para notificações.
- [ ] Território: apenas Portugal.

## Google Play (adiado)
- [ ] Formulário de segurança de dados, eliminação de conta com link web, política de famílias se aplicável.
- [ ] Conta pessoal nova: teste fechado com 12 testadores durante 14 dias.

## Técnico
- [ ] Domínio e HTTPS (Caddy). `Security__TrustProxyHeaders=true` só atrás do proxy.
- [ ] Segredos fortes de produção (`JWT_SIGNING_KEY`, `PASSWORD_PEPPER`, base de dados). Nunca os de desenvolvimento.
- [ ] Serviço de email real, com SPF/DKIM no domínio.
- [ ] Cópias de segurança diárias cifradas da base de dados e teste de restauro.
- [ ] Monitorização e alertas (disponibilidade, erros).
- [ ] 2FA para árbitros e gestores antes de lhes dar acesso.
- [ ] Teste de penetração ou revisão de segurança independente.
