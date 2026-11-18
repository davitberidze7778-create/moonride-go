<template>
  <div class="passenger-shell">
    <v-app-bar app flat height="68" class="passenger-topbar">
      <img src="/g-o-mark.svg" alt="MoonrideGo" class="header-mark">
      <div class="header-brand">Moonride<span>Go</span><small>PASSENGER</small></div>
      <v-spacer />
      <v-btn icon color="#dfe7f5" aria-label="Profile" @click="$router.push({ name: 'profile' })">
        <v-icon>mdi-account-circle-outline</v-icon>
      </v-btn>
    </v-app-bar>
    <main class="passenger-content"><router-view /></main>
    <nav class="passenger-bottom-nav" aria-label="Passenger navigation">
      <button :class="{ selected: $route.name === 'home' }" @click="go('home')"><v-icon>mdi-home-variant-outline</v-icon><span>HOME</span></button>
      <button :class="{ selected: $route.name === 'orders' }" @click="go('orders')"><v-icon>mdi-receipt-text-outline</v-icon><span>ORDERS</span></button>
      <button :class="{ selected: $route.name === 'profile' }" @click="go('profile')"><v-icon>mdi-account-outline</v-icon><span>PROFILE</span></button>
    </nav>
  </div>
</template>

<script>
import supabase from '@/services/supabase'
export default {
  name: 'PassengerShell',
  data() { return { authSubscription: null } },
  mounted() {
    if (!supabase) return
    const { data } = supabase.auth.onAuthStateChange(event => {
      if (event === 'SIGNED_OUT') this.$router.replace({ name: 'auth' })
    })
    this.authSubscription = data.subscription
  },
  beforeDestroy() { if (this.authSubscription) this.authSubscription.unsubscribe() },
  methods: { go(name) { if (this.$route.name !== name) this.$router.push({ name }) } }
}
</script>

<style scoped>
.passenger-shell { min-height:100vh; background:#07152B; }
.passenger-topbar { background:#061225 !important; border-bottom:1px solid rgba(70,133,215,.18); }
.header-mark { width:42px; height:42px; object-fit:contain; margin-right:10px; }
.header-brand { color:#f3f6ff; font-weight:900; letter-spacing:.3px; font-size:15px; line-height:1.1; }
.header-brand span { color:#2F80FF; margin-left:3px; }
.header-brand small { display:block; color:#8292af; font-size:8px; letter-spacing:2px; font-weight:700; margin-top:5px; }
.passenger-content { min-height:100vh; padding:84px 16px 100px; max-width:760px; margin:0 auto; }
.passenger-bottom-nav { position:fixed; z-index:10; left:0; right:0; bottom:0; height:72px; display:flex; justify-content:space-around; align-items:center; background:rgba(7,13,27,.98); border-top:1px solid rgba(70,133,215,.2); padding-bottom:env(safe-area-inset-bottom); }
.passenger-bottom-nav button { flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:4px; height:100%; color:#8494ae; font-size:10px; font-weight:700; }
.passenger-bottom-nav button .v-icon { color:#8494ae; font-size:22px; }
.passenger-bottom-nav button.selected, .passenger-bottom-nav button.selected .v-icon { color:#2F80FF; text-shadow:0 0 14px rgba(72,183,255,.55); }
</style>
