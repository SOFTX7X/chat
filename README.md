# SOFT Chat

Rede social web em português com cadastro, perfis, feed, amizades, conversas privadas e fotos. Stack: Vite + Supabase, pronta para Vercel.

## Configuração obrigatória do banco
1. Abra o projeto Supabase e vá a SQL Editor → New query.
2. Abra `supabase/schema.sql` deste repositório, copie o arquivo inteiro e execute.
3. Em Authentication → URL Configuration, configure o domínio publicado e os redirects.
4. Habilite Email em Authentication → Providers.

## Publicação na Vercel
1. Importe https://github.com/SOFTX7X/chat.
2. Build command: `npm run build`; output directory: `dist`; framework: Vite.
3. Configure `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` nas Environment Variables e publique.
4. Nunca coloque a chave `service_role` ou secret key no frontend nem em variável VITE_.

## Rodar localmente
Requer Node.js 20.19+.

    npm install
    cp .env.example .env.local
    npm run dev

Preencha .env.local com URL e chave publicável do Supabase. Se não configurar variáveis, o app mostra uma tela para informar a conexão durante a sessão.

## Incluído
Cadastro/login, recuperação de senha, perfil e avatar, feed com posts/fotos, curtidas, comentários, pesquisa de pessoas, pedidos de amizade, chat privado em tempo real, envio de fotos, layout responsivo, SQL com tabelas, índices, RLS e Storage.

## Antes de produção
Testar com duas contas reais, configurar SMTP, revisar moderação/denúncias, privacidade, limites anti-spam e as políticas RLS. O SQL cria a estrutura, mas não substitui testes no seu projeto Supabase. Esta primeira versão não inclui chamadas de voz/vídeo, grupos na interface, status de digitação ou push notifications.