<template>
  <div class="profile-page">
    <div class="page-heading"><div class="eyebrow">MoonrideGo · PROFILE</div><h1>ჩემი პროფილი</h1><p>მართე შენი პირადი მონაცემები</p></div>
    <div v-if="loading" class="loading-state"><v-progress-circular indeterminate color="#742BFF" /></div>
    <template v-else>
      <v-card class="profile-card" elevation="0">
        <div class="profile-avatar"><v-icon size="31" color="#742BFF">mdi-account</v-icon></div>
        <div class="profile-email">{{ email }}</div>
        <div class="account-badge"><v-icon x-small color="#742BFF">mdi-check-circle</v-icon> მგზავრის ანგარიში</div>
        <v-alert v-if="message" dense text :type="messageType">{{ message }}</v-alert>
        <v-form @submit.prevent="save">
          <v-text-field v-model.trim="fullName" label="სახელი და გვარი" prepend-inner-icon="mdi-account-outline" outlined dense color="#742BFF" dark />
          <v-text-field v-model.trim="phone" label="ტელეფონის ნომერი" prepend-inner-icon="mdi-phone-outline" outlined dense color="#742BFF" dark />
          <v-text-field :value="email" label="ელფოსტა" prepend-inner-icon="mdi-email-outline" outlined dense disabled dark />
          <v-btn type="submit" block color="#742BFF" class="save-button" :loading="saving" :disabled="saving">ცვლილებების შენახვა</v-btn>
        </v-form>
      </v-card>
      <v-btn block outlined color="#c5cede" class="signout-button" @click="signOut" :loading="signingOut">
        <v-icon left>mdi-logout</v-icon> ანგარიშიდან გამოსვლა
      </v-btn>
    </template>
  </div>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'PassengerProfile',
  data() {
    return { loading: true, saving: false, signingOut: false, userId: '', email: '', fullName: '', phone: '', message: '', messageType: 'info' }
  },
  async mounted() { await this.loadProfile() },
  methods: {
    async loadProfile() {
      this.loading = true
      try {
        if (!supabase) throw new Error('Supabase კავშირი არ არის გამართული.')
        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) throw new Error('შესვლის სესია ვერ მოიძებნა.')
        this.userId = user.id
        this.email = user.email || ''
        const { data, error } = await supabase.from('profiles').select('full_name,phone,role').eq('id', user.id).maybeSingle()
        if (error) throw error
        if (!data || data.role !== 'passenger') throw new Error('მგზავრის პროფილი ვერ მოიძებნა.')
        this.fullName = data.full_name || ''
        this.phone = data.phone || ''
      } catch (error) {
        this.messageType = 'error'
        this.message = error.message || 'პროფილის ჩატვირთვა ვერ მოხერხდა.'
      } finally {
        this.loading = false
      }
    },
    async save() {
      this.message = ''
      if (!this.fullName || !this.phone) {
        this.messageType = 'warning'
        this.message = 'სახელი და ტელეფონი აუცილებელია.'
        return
      }
      this.saving = true
      try {
        const { error } = await supabase.from('profiles')
          .update({ full_name: this.fullName, phone: this.phone })
          .eq('id', this.userId)
        if (error) throw error
        this.messageType = 'success'
        this.message = 'პროფილი წარმატებით განახლდა.'
      } catch (error) {
        this.messageType = 'error'
        this.message = error.message || 'შენახვა ვერ მოხერხდა.'
      } finally {
        this.saving = false
      }
    },
    async signOut() {
      this.signingOut = true
      try {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
        this.$router.replace({ name: 'auth' })
      } catch (error) {
        this.messageType = 'error'
        this.message = error.message || 'გამოსვლა ვერ მოხერხდა.'
      } finally {
        this.signingOut = false
      }
    }
  }
}
</script>

<style scoped>
.profile-page { color: #e3e9f5; }
.page-heading .eyebrow { color: #742BFF; font-size: 9px; font-weight: 800; letter-spacing: 2px; }
.page-heading h1 { color: #f4f6fb; margin: 7px 0 4px; font-size: 25px; font-weight: 800; }
.page-heading p { color: #8796b1; margin: 0 0 18px; font-size: 12px; }
.loading-state { display: flex; justify-content: center; padding: 70px; }
.profile-card { background: #102544 !important; border: 1px solid rgba(82,145,225,.18) !important; border-radius: 17px !important; color: #e3e9f5; padding: 22px 18px; }
.profile-avatar { margin: 0 auto 12px; width: 64px; height: 64px; border-radius: 20px; display: flex; justify-content: center; align-items: center; background: #25194E; border: 1px solid rgba(116,43,255,.22); }
.profile-email { text-align: center; color: #e9eef8; font-weight: 700; font-size: 13px; }
.account-badge { text-align: center; color: #99a8bd; font-size: 10px; margin: 7px 0 22px; }
.save-button { color: #ffffff !important; border-radius: 10px; font-weight: 800; box-shadow: 0 0 18px rgba(116,43,255,.25); box-shadow: 0 0 18px rgba(116,43,255,.25); }
.signout-button { margin-top: 15px; border-radius: 10px; }
</style>
