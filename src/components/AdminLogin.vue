<template>
  <v-container fluid class="moonride-login">
    <v-row justify="center" align="center" class="login-row">
      <v-col cols="12" sm="8" md="5" lg="4">
        <v-card dark color="#101827" class="pa-6">
          <div class="text-center mb-6">
            <h1 class="mb-2">MOONRIDE GO</h1>
            <div class="subtitle-1">MASTER ADMIN</div>
          </div>
          <v-alert v-if="errorMessage" type="error" dense>{{ errorMessage }}</v-alert>
          <v-text-field v-model.trim="email" label="Administrator email" type="email" autocomplete="username" outlined dark :disabled="loading" />
          <v-text-field v-model="password" label="Password" type="password" autocomplete="current-password" outlined dark :disabled="loading" @keyup.enter="signIn" />
          <v-btn block color="amber darken-2" dark :loading="loading" :disabled="!email || !password || loading" @click="signIn">Sign in securely</v-btn>
          <div class="caption text-center mt-4">Authorized MASTER ADMIN accounts only</div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  data() {
    return { email: '', password: '', loading: false, errorMessage: '' }
  },
  async created() {
    // Reuse a valid saved MASTER ADMIN session after the app is reopened.
    if (!supabase) return
    try {
      const { data, error } = await supabase.auth.getUser()
      if (error || !data || !data.user) return

      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .maybeSingle()

      if (!profileError && profile && profile.role === 'master_admin') {
        this.$router.replace('/admin')
      } else {
        await supabase.auth.signOut()
      }
    } catch (error) {
      // Keep the login screen available if session restoration cannot complete.
      this.errorMessage = 'Please sign in again to continue.'
    }
  },
  methods: {
    async signIn() {
      this.errorMessage = ''
      if (!supabase) {
        this.errorMessage = 'Supabase is not configured. Set VUE_APP_SUPABASE_URL and VUE_APP_SUPABASE_ANON_KEY before building.'
        return
      }
      this.loading = true
      try {
        const { data, error } = await supabase.auth.signInWithPassword({ email: this.email, password: this.password })
        if (error) throw error
        const user = data && data.user
        if (!user) throw new Error('Authentication did not return a user.')
        const { data: profile, error: profileError } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
        if (profileError) throw profileError
        if (!profile || profile.role !== 'master_admin') {
          await supabase.auth.signOut()
          throw new Error('This account is not authorized as MASTER ADMIN.')
        }
        this.$router.replace('/admin')
      } catch (error) {
        this.errorMessage = error.message || 'Unable to sign in.'
      } finally {
        this.loading = false
      }
    }
  }
}
</script>

<style scoped>
.moonride-login {
  background: #080e18;
  min-height: 100vh;
  padding-bottom: env(safe-area-inset-bottom);
}
.login-row {
  min-height: 88vh;
}
</style>
