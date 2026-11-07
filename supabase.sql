-- Tabelle für den App-Sync: ein Datensatz pro Eintrag, nur für den eigenen Account sichtbar
create table if not exists public.records (
  user_id    uuid    not null default auth.uid() references auth.users(id) on delete cascade,
  col        text    not null,
  id         text    not null,
  data       jsonb   not null,
  updated_at bigint  not null,
  deleted    boolean not null default false,
  synced_at  timestamptz not null default clock_timestamp(),
  primary key (user_id, col, id)
);
create index if not exists records_user_synced on public.records (user_id, synced_at);

-- Neuere Änderung gewinnt; Server setzt synced_at bei jeder Änderung neu
create or replace function public.records_guard() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return null;
  end if;
  new.synced_at := clock_timestamp();
  return new;
end $$;
drop trigger if exists records_guard on public.records;
create trigger records_guard before insert or update on public.records
  for each row execute function public.records_guard();

alter table public.records enable row level security;
drop policy if exists "own rows" on public.records;
create policy "own rows" on public.records for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
