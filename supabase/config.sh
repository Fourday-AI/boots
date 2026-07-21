#!/usr/bin/env bash
# Boots telemetry — PUBLIC Supabase config. Safe to commit (like Firebase public
# config): RLS denies the anon key all direct table access; every read and write
# goes through an edge function that uses the service-role key server-side.
#
# EMPTY until a Boots telemetry project is provisioned. While blank, the sync is a
# no-op and nothing leaves the machine — the whole remote layer is dormant, exactly
# like the update check with no git remote. To go live: create a Supabase project,
# deploy supabase/functions/*, apply supabase/migrations/*, then fill these two in.
BOOTS_SUPABASE_URL="${BOOTS_SUPABASE_URL:-}"
BOOTS_SUPABASE_ANON_KEY="${BOOTS_SUPABASE_ANON_KEY:-}"
