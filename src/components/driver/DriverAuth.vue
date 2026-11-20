<template>
  <div class="driver-auth">
    <img src="/g-o-mark.svg" alt="MOONRIDE GO" class="driver-logo">
    <h1>MOONRIDE <span>DRIVER</span></h1>
    <p>მძღოლის სამუშაო აპლიკაცია</p>
    <v-card class="driver-card" elevation="0">
      <h2>მძღოლის შესვლა</h2>
      <v-alert v-if="message" dense text :type="messageType">{{ message }}</v-alert>
      <v-form @submit.prevent="signIn">
        <v-text-field v-model.trim="email" label="ელფოსტა" type="email" outlined dense dark autocomplete="username"/>
        <v-text-field v-model="password" label="პაროლი" type="password" outlined dense dark autocomplete="current-password" @keyup.enter="signIn"/>
        <v-btn type="submit" block large color="#2F80FF" dark :loading="busy" :disabled="busy">შესვლა</v-btn>
      </v-form>
      <div class="secure-note">დაცული ავტორიზაცია · Supabase</div>
    </v-card>
  </div>
</template>
<script>
import supabase from '@/services/supabase'
export default {
  name: 'DriverAuth',
  data: () => ({ email: '', password: '', busy: false, message: '', messageType: 'info' }),
  methods: {
    async signIn() {
      this.message = ''
      if (!supabase) { this.messageType = 'error'; this.message = 'Supabase კონფიგურაცია მიუწვდომელია.'; return }
      if (!this.email || !this.password) { this.messageType = 'warning'; this.message = 'შეავსე ელფოსტა და პაროლი.'; return }
      this.busy = true
      try {
        const { data, error } = await supabase.auth.signInWithPassword({ email: this.email, password: this.password })
        if (error) throw error
        const { data: profile, error: profileError } = await supabase.from('profiles').select('role').eq('id', data.user.id).maybeSingle()
        if (profileError || !profile || profile.role !== 'driver') {
          await supabase.auth.signOut()
          throw new Error('ეს ანგარიში არ არის დადასტურებული მძღოლის ანგარიშად.')
        }
        this.$router.replace({ name: 'driver-home' })
      } catch (error) {
        this.messageType = 'error'
        this.message = error.message || 'შესვლა ვერ მოხერხდა.'
      } finally { this.busy = false }
    }
  }
}
</script>
<style scoped>
.driver-auth{min-height:100vh;background:#07152B;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;color:#F2F7FF}
.driver-logo{width:94px;height:94px;object-fit:contain;margin-bottom:10px}
h1{font-size:20px;font-weight:900;letter-spacing:1px;margin:0}h1 span{color:#48B7FF}
p{color:#A8C6E8;font-size:12px;margin:7px 0 22px}
.driver-card{width:100%;max-width:420px;padding:22px;background:#102544!important;border:1px solid rgba(82,145,225,.2)!important;border-radius:16px!important;color:#F2F7FF}
.driver-card h2{font-size:18px;margin:0 0 18px}.secure-note{text-align:center;color:#91A8C7;font-size:10px;margin-top:16px}
</style>