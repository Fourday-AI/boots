#!/usr/bin/env bash
# Boots telemetry — PUBLIC Supabase config. Safe to commit (like Firebase public
# config): RLS denies the anon key all direct table access; every read and write
# goes through an edge function that uses the service-role key server-side.
#
# The project below is LIVE. Even so, nothing is sent unless the user has opted in:
# boots-telemetry-sync exits immediately while `telemetry` is `off`, which is the
# default. See the Privacy & telemetry section of README.md for exactly what a
# consenting install transmits.
#
# Blanking BOOTS_SUPABASE_URL (or exporting it empty) makes the whole remote layer
# dormant — the sync becomes a no-op, exactly like the update check with no git
# remote. Point these at your own project to self-host: create a Supabase project,
# deploy supabase/functions/*, apply supabase/migrations/*, then swap these two.
BOOTS_SUPABASE_URL="${BOOTS_SUPABASE_URL:-https://kamchoalzvaynjvogpkf.supabase.co}"
BOOTS_SUPABASE_ANON_KEY="${BOOTS_SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImthbWNob2FsenZheW5qdm9ncGtmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NzIxNTcsImV4cCI6MjEwMDM0ODE1N30.fHaVB1KCf3885fKjJshpcML3q-ie1a8jrKJloTOkhKs}"
