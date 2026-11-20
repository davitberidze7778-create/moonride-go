<template>
  <v-container fluid class="moonride-login">
    <v-row justify="center" align="center" class="login-row">
      <v-col cols="12" sm="8" md="5" lg="4" xl="3">
        <v-card dark outlined class="login-card pa-6 pa-md-8">
          <div class="text-center mb-7">
            <moonride-logo />
            <div class="login-heading">Administrator Access</div>
            <div class="login-subheading">Secure sign in to the MOONRIDE GO control center</div>
          </div>
          <v-alert v-if="errorMessage" type="error" dense text>{{ errorMessage }}</v-alert>
          <v-text-field
            v-model.trim="email"
            label="Administrator email"
            type="email"
            autocomplete="username"
            outlined
            dark
            color="blue lighten-2"
            prepend-inner-icon="mdi-email-outline"
            :disabled="loading"
          />
          <v-text-field
            v-model="password"
            label="Password"
            type="password"
            autocomplete="current-password"
            outlined
            dark
            color="blue lighten-2"
            prepend-inner-icon="mdi-lock-outline"
            :disabled="loading"
            @keyup.enter="signIn"
          />
          <v-btn block color="blue darken-1" large :loading="loading" :disabled="!email || !password || loading" @click="signIn">
            <v-icon left>mdi-shield-lock</v-icon> Sign in securely
          </v-btn>
          <div class="login-footnote">Authorized MASTER ADMIN accounts only</div>
        </v-card>
        <div class="text-center caption mt-5 login-version">MOONRIDE GO · MASTER ADMIN</div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'
import MoonrideLogo from '@/components/Logo'

export default {
  components: { MoonrideLogo },
  data() {
    return { email: '', password: '', loading: false, errorMessage: '' }
  },
  async created() {
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
      this.errorMessage = 'Please sign in again to continue.'
    }
  },
  methods: {
    async signIn() {
      this.errorMessage = ''
      if (!supabase) {
        this.errorMessage = 'Supabase is not configured. Set VUE_APP_SUPABASE_URL and VUE_APP_SUPABASE_PUBLISHABLE_KEY.'
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
  min-height: 100vh;
  display: flex;
  align-items: center;
  background: radial-gradient(circle at 50% 28%, rgba(37, 99, 235, .13), transparent 38%), #080e1c;
  padding: 18px;
}
.login-row { min-height: 88vh; width: 100%; }
.login-card {
  background: linear-gradient(145deg, #101d35, #0b1426) !important;
  border-color: rgba(111, 142, 199, .28) !important;
  border-radius: 20px !important;
  box-shadow: 0 24px 70px rgba(0, 0, 0, .35);
}
.login-heading { color: #edf3ff; font-size: 18px; font-weight: 800; margin-top: 5px; }
.login-subheading { color: #8798b5; font-size: 12px; margin-top: 7px; }
.login-footnote { color: #7788a4; font-size: 11px; text-align: center; margin-top: 18px; }
.login-version { color: #657795 !important; letter-spacing: 1.5px; }
</style>