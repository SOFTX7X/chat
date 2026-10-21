-- SOFT CHAT — esquema completo Supabase/PostgreSQL
-- Supabase Dashboard > SQL Editor > New query > cole e execute TODO este arquivo.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(char_length(username) between 3 and 24 and username ~ '^[A-Za-z0-9_]+$'),
 display_name text not null default 'Pessoa' check(char_length(display_name) between 1 and 60),
 bio text check(char_length(coalesce(bio,''))<=240),
 avatar_url text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.friend_requests (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id) on delete cascade,
 receiver_id uuid not null references public.profiles(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','accepted')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint friend_requests_no_self check(sender_id<>receiver_id),
 constraint friend_requests_unique_pair unique(sender_id,receiver_id)
);
create table if not exists public.conversations (
 id uuid primary key default gen_random_uuid(),
 title text check(char_length(coalesce(title,''))<=100),
 is_group boolean not null default false,
 created_by uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 joined_at timestamptz not null default now(),
 last_read_at timestamptz,
 primary key(conversation_id,user_id)
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text check(char_length(coalesce(body,''))<=5000),
 image_url text,
 created_at timestamptz not null default now(),
 constraint messages_need_content check(nullif(trim(coalesce(body,'')),'') is not null or image_url is not null)
);
create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text check(char_length(coalesce(body,''))<=3000),
 image_url text,
 created_at timestamptz not null default now(),
 constraint posts_need_content check(nullif(trim(coalesce(body,'')),'') is not null or image_url is not null)
);
create table if not exists public.post_likes (
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete cascade,
 kind text not null check(kind in ('friend_request','friend_accepted','message','like','comment')),
 reference_id uuid,
 read_at timestamptz,
 created_at timestamptz not null default now()
);

create index if not exists profiles_username_idx on public.profiles(lower(username));
create index if not exists requests_receiver_idx on public.friend_requests(receiver_id,status);
create index if not exists requests_sender_idx on public.friend_requests(sender_id,status);
create index if not exists members_user_idx on public.conversation_members(user_id,conversation_id);
create index if not exists messages_conversation_idx on public.messages(conversation_id,created_at desc);
create index if not exists posts_created_idx on public.posts(created_at desc);
create index if not exists posts_user_idx on public.posts(user_id,created_at desc);
create index if not exists comments_post_idx on public.comments(post_id,created_at);
create index if not exists notifications_user_idx on public.notifications(user_id,created_at desc);

create or replace function public.soft_chat_username(input_name text,input_id uuid)
returns text language sql immutable set search_path='' as $$
 select left(coalesce(nullif(regexp_replace(lower(translate(coalesce(input_name,''),'áàâãäåÁÀÂÃÄÅéèêëÉÈÊËíìîïÍÌÎÏóòôõöÓÒÔÕÖúùûüÚÙÛÜçÇñÑ','aaaaaaAAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcCnN')),'[^a-z0-9_]','','g'),''),'usuario'),17)||'_'||left(replace(input_id::text,'-',''),5);
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path='' as $$
declare n text;
begin
 n:=coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),nullif(split_part(coalesce(new.email,''),'@',1),''),'Pessoa');
 insert into public.profiles(id,username,display_name) values(new.id,public.soft_chat_username(n,new.id),left(n,60)) on conflict(id) do nothing;
 return new;
end;
$$;
drop trigger if exists soft_chat_auth_user_created on auth.users;
create trigger soft_chat_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.soft_chat_updated_at()
returns trigger language plpgsql set search_path='' as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.soft_chat_updated_at();
drop trigger if exists friend_requests_updated_at on public.friend_requests;
create trigger friend_requests_updated_at before update on public.friend_requests for each row execute procedure public.soft_chat_updated_at();
drop trigger if exists conversations_updated_at on public.conversations;
create trigger conversations_updated_at before update on public.conversations for each row execute procedure public.soft_chat_updated_at();

create or replace function public.is_conversation_member(target uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.conversation_members m where m.conversation_id=target and m.user_id=(select auth.uid()));
$$;

alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.notifications enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using(true);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated with check(id=(select auth.uid()));
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));

drop policy if exists requests_read_participants on public.friend_requests;
create policy requests_read_participants on public.friend_requests for select to authenticated using(sender_id=(select auth.uid()) or receiver_id=(select auth.uid()));
drop policy if exists requests_send_self on public.friend_requests;
create policy requests_send_self on public.friend_requests for insert to authenticated with check(sender_id=(select auth.uid()) and receiver_id<>(select auth.uid()));
drop policy if exists requests_accept_recipient on public.friend_requests;
create policy requests_accept_recipient on public.friend_requests for update to authenticated using(receiver_id=(select auth.uid()) and status='pending') with check(receiver_id=(select auth.uid()) and status='accepted');
drop policy if exists requests_delete_pending on public.friend_requests;
create policy requests_delete_pending on public.friend_requests for delete to authenticated using((sender_id=(select auth.uid()) or receiver_id=(select auth.uid())) and status='pending');

drop policy if exists conversations_read_member on public.conversations;
create policy conversations_read_member on public.conversations for select to authenticated using(public.is_conversation_member(id) or created_by=(select auth.uid()));
drop policy if exists conversations_create_self on public.conversations;
create policy conversations_create_self on public.conversations for insert to authenticated with check(created_by=(select auth.uid()));
drop policy if exists conversations_update_member on public.conversations;
create policy conversations_update_member on public.conversations for update to authenticated using(public.is_conversation_member(id)) with check(public.is_conversation_member(id));

drop policy if exists members_read_participants on public.conversation_members;
create policy members_read_participants on public.conversation_members for select to authenticated using(user_id=(select auth.uid()) or public.is_conversation_member(conversation_id));
drop policy if exists members_add_creator_or_self on public.conversation_members;
create policy members_add_creator_or_self on public.conversation_members for insert to authenticated with check(
 user_id=(select auth.uid()) or exists(select 1 from public.conversations c where c.id=conversation_id and c.created_by=(select auth.uid()))
);
drop policy if exists members_update_own_read_at on public.conversation_members;
create policy members_update_own_read_at on public.conversation_members for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists members_delete_own on public.conversation_members;
create policy members_delete_own on public.conversation_members for delete to authenticated using(user_id=(select auth.uid()));

drop policy if exists messages_read_members on public.messages;
create policy messages_read_members on public.messages for select to authenticated using(public.is_conversation_member(conversation_id));
drop policy if exists messages_insert_members on public.messages;
create policy messages_insert_members on public.messages for insert to authenticated with check(sender_id=(select auth.uid()) and public.is_conversation_member(conversation_id));

drop policy if exists posts_read_signed_in on public.posts;
create policy posts_read_signed_in on public.posts for select to authenticated using(true);
drop policy if exists posts_insert_own on public.posts;
create policy posts_insert_own on public.posts for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists posts_update_own on public.posts;
create policy posts_update_own on public.posts for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists posts_delete_own on public.posts;
create policy posts_delete_own on public.posts for delete to authenticated using(user_id=(select auth.uid()));

drop policy if exists likes_read_signed_in on public.post_likes;
create policy likes_read_signed_in on public.post_likes for select to authenticated using(true);
drop policy if exists likes_insert_own on public.post_likes;
create policy likes_insert_own on public.post_likes for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists likes_delete_own on public.post_likes;
create policy likes_delete_own on public.post_likes for delete to authenticated using(user_id=(select auth.uid()));

drop policy if exists comments_read_signed_in on public.comments;
create policy comments_read_signed_in on public.comments for select to authenticated using(true);
drop policy if exists comments_insert_own on public.comments;
create policy comments_insert_own on public.comments for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists comments_update_own on public.comments;
create policy comments_update_own on public.comments for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists comments_delete_own on public.comments;
create policy comments_delete_own on public.comments for delete to authenticated using(user_id=(select auth.uid()));

drop policy if exists notifications_read_own on public.notifications;
create policy notifications_read_own on public.notifications for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('social-media','social-media',true,8388608,array['image/jpeg','image/png','image/webp','image/gif','image/avif'])
on conflict(id) do update set public=true,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif','image/avif'];
drop policy if exists social_media_read on storage.objects;
create policy social_media_read on storage.objects for select to authenticated using(bucket_id='social-media');
drop policy if exists social_media_insert_own_folder on storage.objects;
create policy social_media_insert_own_folder on storage.objects for insert to authenticated with check(bucket_id='social-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists social_media_update_own_folder on storage.objects;
create policy social_media_update_own_folder on storage.objects for update to authenticated using(bucket_id='social-media' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='social-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists social_media_delete_own_folder on storage.objects;
create policy social_media_delete_own_folder on storage.objects for delete to authenticated using(bucket_id='social-media' and (storage.foldername(name))[1]=(select auth.uid())::text);

do $$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
  alter publication supabase_realtime add table public.messages;
 end if;
exception when undefined_object then null;
end $$;

grant usage on schema public to authenticated;
grant select,insert,update,delete on public.profiles,public.friend_requests,public.conversations,public.conversation_members,public.messages,public.posts,public.post_likes,public.comments,public.notifications to authenticated;
