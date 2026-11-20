import { createClient } from '@supabase/supabase-js'

// These are public client-side values. Never expose a Supabase secret/service_role key.
const supabaseUrl = process.env.VUE_APP_SUPABASE_URL
const supabasePublishableKey =
  process.env.VUE_APP_SUPABASE_PUBLISHABLE_KEY ||
  process.env.VUE_APP_SUPABASE_ANON_KEY

const supabase = (supabaseUrl && supabasePublishableKey)
  ? createClient(supabaseUrl, supabasePublishableKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false
      }
    })
  : null

export default supabase
