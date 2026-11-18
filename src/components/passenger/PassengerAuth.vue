<template>
  <div class="auth-page">
    <div class="auth-backdrop"></div>
    <div class="auth-top">
      <img src="/moonride-go-mark.svg" alt="MOONRIDE GO" class="auth-logo">
      <div class="auth-wordmark">MOONRIDE <span>GO</span></div>
      <div class="auth-caption">YOUR RIDE. YOUR WAY.</div>
    </div>

    <v-card class="auth-card" elevation="0">
      <div class="auth-tabs">
        <button :class="{ active: mode === 'signin' }" @click="setMode('signin')">შესვლა</button>
        <button :class="{ active: mode === 'signup' }" @click="setMode('signup')">რეგისტრაცია</button>
      </div>

      <div class="auth-heading">
        <h1>{{ mode === 'signup' ? 'შექმენი ანგარიში' : mode === 'reset' ? 'პაროლის აღდგენა' : 'კეთილი იყოს შენი დაბრუნება' }}</h1>
        <p>{{ mode === 'signup' ? 'დარეგისტრირდი და ისარგებლე MOONRIDE GO-ით' : mode === 'reset' ? 'გამოგიგზავნით პაროლის აღდგენის ბმულს' : 'შედი შენს მგზავრის ანგარიშში' }}</p>
      </div>

      <v-alert v-if="message" :type="messageType" dense text class="auth-alert">{{ message }}</v-alert>

      <v-form v-if="mode !== 'reset'" ref="authForm" @submit.prevent="submit">
        <v-text-field
          v-if="mode === 'signup'"
          v-model.trim="fullName"
          label="სახელი და გვარი"
          prepend-inner-icon="mdi-account-outline"
          outlined dense color="#f5bd18" dark
          autocomplete="name"
          :disabled="busy"
        />
        <v-text-field
          v-if="mode === 'signup'"
          v-model.trim="phone"
          label="ტელეფონის ნომერი"
          prepend-inner-icon="mdi-phone-outline"
          outlined dense color="#f5bd18" dark
          autocomplete="tel"
          :disabled="busy"
        />
        <v-text-field
          v-model.trim="email"
          label="ელფოსტა"
          prepend-inner-icon="mdi-email-outline"
          type="email" outlined dense color="#f5bd18" dark
          autocomplete="email" :disabled="busy"
        />
        <v-text-field
          v-model="password"
          label="პაროლი"
          prepend-inner-icon="mdi-lock-outline"
          :append-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
          @click:append="showPassword = !showPassword"
          :type="showPassword ? 'text' : 'password'"
          outlined dense color="#f5bd18" dark
          :autocomplete="mode === 'signup' ? 'new-password' : 'current-password'"
          :disabled="busy"
          @keyup.enter="submit"
        />
        <v-text-field
          v-if="mode === 'signup'"
          v-model="confirmPassword"
          label="გაიმეორე პაროლი"
          prepend-inner-icon="mdi-lock-check-outline"
          :type="showPassword ? 'text' : 'password'"
          outlined dense color="#f5bd18" dark
          autocomplete="new-password" :disabled="busy"
        />
        <div v-if="mode === 'signin'" class="forgot-row">
          <button type="button" @click="setMode('reset')">დაგავიწყდა პაროლი?</button>
        </div>
        <v-btn type="submit" block large color="#f5bd18" dark class="auth-submit" :loading="busy" :disabled="busy">
          {{ mode === 'signup' ? 'ანგარიშის შექმნა' : 'შესვლა' }}
        </v-btn>
      </v-form>

      <v-form v-else @submit.prevent="sendReset">
        <v-text-field v-model.trim="email" label="ელფოსტა" prepend-inner-icon="mdi-email-outline"
          type="email" outlined dense color="#f5bd18" dark autocomplete="email" :disabled="busy" />
        <v-btn type="submit" block large color="#f5bd18" dark class="auth-submit" :loading="busy">
          აღდგენის ბმულის გაგზავნა
        </v-btn>
      </v-form>

      <button v-if="mode === 'reset'" class="back-to-login" @click="setMode('signin')">შესვლაზე დაბრუნება</button>

      <div class="auth-footer">
        <v-icon small color="#f5bd18">mdi-shield-check-outline</v-icon>
        დაცული ავტორიზაცია Supabase-ის მეშვეობით
      </div>
    </v-card>
    <div class="auth-version">MOONRIDE GO · PASSENGER</div>
  </div>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'PassengerAuth',
  data() {
    return {
      mode: 'signin',
      fullName: '',
      phone: '',
      email: '',
      password: '',
      confirmPassword: '',
      showPassword: false,
      busy: false,
      message: '',
      messageType: 'info'
    }
  },
  methods: {
    setMode(mode) {
      this.mode = mode
      this.message = ''
      this.password = ''
      this.confirmPassword = ''
    },
    async submit() {
      this.message = ''
      if (!supabase) {
        this.messageType = 'error'
        this.message = 'Supabase-ის კავშირი არ არის გამართული. შეამოწმე აპის კონფიგურაცია.'
        return
      }
      if (!this.email || !this.password) {
        this.messageType = 'warning'
        this.message = 'შეავსე ელფოსტისა და პაროლის ველები.'
        return
      }
      if (this.mode === 'signup') {
        if (!this.fullName || !this.phone) {
          this.messageType = 'warning'
          this.message = 'რეგისტრაციისთვის შეავსე სახელი, გვარი და ტელეფონი.'
          return
        }
        if (this.password.length < 8) {
          this.messageType = 'warning'
          this.message = 'პაროლი უნდა შეიცავდეს მინიმუმ 8 სიმბოლოს.'
          return
        }
        if (this.password !== this.confirmPassword) {
          this.messageType = 'warning'
          this.message = 'პაროლები ერთმანეთს არ ემთხვევა.'
          return
        }
      }

      this.busy = true
      try {
        if (this.mode === 'signup') {
          const { data, error } = await supabase.auth.signUp({
            email: this.email,
            password: this.password,
            options: { data: { full_name: this.fullName, phone: this.phone } }
          })
          if (error) throw error
          if (data.session && data.user) {
            const { error: profileError } = await supabase
              .from('profiles')
              .update({ full_name: this.fullName, phone: this.phone })
              .eq('id', data.user.id)
            if (profileError) throw profileError
            this.messageType = 'success'
            this.message = 'ანგარიში შეიქმნა. შეგიძლია აპლიკაციის გამოყენება.'
            this.$router.replace({ name: 'home' })
          } else {
            this.messageType = 'success'
            this.message = 'რეგისტრაცია დასრულდა. შეამოწმე ელფოსტა ანგარიშის დასადასტურებლად, შემდეგ შედი აპლიკაციაში.'
            this.mode = 'signin'
            this.password = ''
          }
        } else {
          const { data, error } = await supabase.auth.signInWithPassword({
            email: this.email,
            password: this.password
          })
          if (error) throw error
          const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('role')
            .eq('id', data.user.id)
            .maybeSingle()
          if (profileError || !profile || profile.role !== 'passenger') {
            await supabase.auth.signOut()
            throw new Error('ეს ანგარიში მგზავრის ანგარიშად არ არის რეგისტრირებული.')
          }
          this.$router.replace({ name: 'home' })
        }
      } catch (error) {
        this.messageType = 'error'
        this.message = this.translateError(error && error.message ? error.message : 'დაფიქსირდა შეცდომა.')
      } finally {
        this.busy = false
      }
    },
    async sendReset() {
      if (!supabase || !this.email) {
        this.messageType = 'warning'
        this.message = 'შეიყვანე ელფოსტის მისამართი.'
        return
      }
      this.busy = true
      this.message = ''
      try {
        const { error } = await supabase.auth.resetPasswordForEmail(this.email)
        if (error) throw error
        this.messageType = 'success'
        this.message = 'თუ ეს ელფოსტა რეგისტრირებულია, პაროლის აღდგენის ბმული გამოგზავნილია.'
      } catch (error) {
        this.messageType = 'error'
        this.message = this.translateError(error.message)
      } finally {
        this.busy = false
      }
    },
    translateError(message) {
      const text = String(message || '')
      if (/Invalid login credentials/i.test(text)) return 'ელფოსტა ან პაროლი არასწორია.'
      if (/Email not confirmed/i.test(text)) return 'ელფოსტა ჯერ არ არის დადასტურებული. შეამოწმე ელფოსტა.'
      if (/User already registered/i.test(text)) return 'ეს ელფოსტა უკვე რეგისტრირებულია. სცადე შესვლა.'
      if (/Password should be at least/i.test(text)) return 'პაროლი ძალიან მოკლეა.'
      if (/rate limit/i.test(text)) return 'მოთხოვნების ლიმიტი ამოიწურა. ცოტა ხანში სცადე.'
      return text
    }
  }
}
</script>

<style scoped>
.auth-page { min-height: 100vh; position: relative; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; padding: 34px 18px 24px; overflow: hidden; background: radial-gradient(circle at 50% 8%, #18294b 0, #0b1428 34%, #080e1c 76%); }
.auth-backdrop { position: absolute; width: 360px; height: 360px; top: -180px; border-radius: 50%; background: rgba(245,189,24,.09); filter: blur(80px); }
.auth-top { z-index: 1; display: flex; flex-direction: column; align-items: center; margin: 5px 0 22px; }
.auth-logo { width: 76px; height: 76px; object-fit: contain; }
.auth-wordmark { color: #f2f5fc; font-size: 20px; font-weight: 900; letter-spacing: 1.2px; margin-top: 8px; }
.auth-wordmark span { color: #f5bd18; }
.auth-caption { color: #8292af; font-size: 9px; letter-spacing: 2.3px; margin-top: 5px; }
.auth-card { z-index: 1; width: 100%; max-width: 450px; border: 1px solid rgba(150,170,210,.18) !important; border-radius: 18px !important; padding: 22px 20px 17px; background: rgba(14,24,43,.96) !important; }
.auth-tabs { display: flex; padding: 4px; background: #091323; border-radius: 11px; margin-bottom: 22px; }
.auth-tabs button { flex: 1; color: #8d9bb4; border-radius: 8px; min-height: 39px; font-size: 13px; font-weight: 700; }
.auth-tabs button.active { color: #101827; background: #f5bd18; }
.auth-heading h1 { margin: 0; color: #f2f5fc; font-size: 22px; font-weight: 800; }
.auth-heading p { color: #8c9bb5; font-size: 12px; margin: 8px 0 18px; }
.auth-alert { font-size: 12px; }
.forgot-row { display: flex; justify-content: flex-end; margin: -7px 0 17px; }
.forgot-row button, .back-to-login { color: #f5c844; font-size: 12px; font-weight: 600; }
.auth-submit { color: #111827 !important; font-weight: 800; letter-spacing: .3px; border-radius: 10px; margin-top: 5px; }
.auth-footer { color: #8190a9; font-size: 10px; display: flex; align-items: center; justify-content: center; gap: 7px; border-top: 1px solid rgba(150,170,210,.12); padding-top: 16px; margin-top: 19px; }
.back-to-login { display: block; margin: 14px auto 0; }
.auth-version { z-index: 1; color: #566681; font-size: 9px; letter-spacing: 1.8px; margin-top: 20px; }
</style>
