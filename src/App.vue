<template>
  <v-app dark class="moonride-shell">
    <v-navigation-drawer
      v-if="!isLoginPage"
      app
      dark
      color="#070d1b"
      width="254"
      :permanent="!$vuetify.breakpoint.mobile"
      :temporary="$vuetify.breakpoint.mobile"
      :value="!$vuetify.breakpoint.mobile || mobileDrawer"
      @input="mobileDrawer = $event"
      class="moonride-sidebar"
    >
      <moonride-logo />
      <v-divider class="sidebar-divider" />
      <div class="sidebar-section-label">WORKSPACE</div>
      <v-list dense nav class="sidebar-menu">
        <v-list-item
          v-for="item in adminLinks"
          :key="item.label"
          :to="item.to || undefined"
          :disabled="item.disabled"
          link
          exact
          active-class="sidebar-item-active"
          class="sidebar-item"
          @click="mobileDrawer = false"
        >
          <v-list-item-icon>
            <v-icon>{{ item.icon }}</v-icon>
          </v-list-item-icon>
          <v-list-item-content>
            <v-list-item-title>{{ item.label }}</v-list-item-title>
          </v-list-item-content>
          <v-list-item-action v-if="item.disabled">
            <span class="coming-soon">SOON</span>
          </v-list-item-action>
        </v-list-item>
      </v-list>
      <template v-slot:append>
        <div class="sidebar-account" v-if="userEmail">
          <div class="account-avatar"><v-icon color="#dbe6ff">mdi-shield-account</v-icon></div>
          <div class="account-copy">
            <div class="account-title">Master Admin</div>
            <div class="account-email">{{ userEmail }}</div>
          </div>
        </div>
        <v-btn text block class="sidebar-signout" @click="signOut">
          <v-icon left small>mdi-logout</v-icon> Sign Out
        </v-btn>
      </template>
    </v-navigation-drawer>

    <v-app-bar v-if="!isLoginPage" app flat dark height="70" class="moonride-topbar">
      <v-app-bar-nav-icon
        v-if="$vuetify.breakpoint.mobile"
        aria-label="Open navigation menu"
        @click.stop="mobileDrawer = !mobileDrawer"
      />
      <div class="topbar-title">
        <span>MOONRIDE GO</span>
        <small> / MASTER ADMIN CONTROL CENTER</small>
      </div>
      <v-spacer />
      <v-chip small outlined color="blue-grey lighten-1" class="topbar-secure">
        <v-icon left x-small color="success">mdi-shield-check</v-icon>
        SECURE ADMIN
      </v-chip>
    </v-app-bar>

    <v-main :class="isLoginPage ? 'login-background' : 'admin-background'">
      <router-view />
    </v-main>
  </v-app>
</template>

<script>
import supabase from '@/services/supabase'
import MoonrideLogo from '@/components/Logo'

export default {
  name: 'App',
  components: { MoonrideLogo },
  data() {
    return {
      userEmail: '',
      mobileDrawer: false,
      authSubscription: null,
      adminLinks: [
        { label: 'Dashboard', to: '/admin', icon: 'mdi-view-dashboard-outline' },
        { label: 'Drivers', to: '/adminAllDrivers', icon: 'mdi-car-multiple' },
        { label: 'Passengers', to: '/adminAllClients', icon: 'mdi-account-group-outline' },
        { label: 'Vehicles', to: '/adminVehicles', icon: 'mdi-car-side' },
        { label: 'Rides & Quotes', to: '/adminActivity', icon: 'mdi-route' },
        { label: 'Tariffs & Pricing', icon: 'mdi-cash-multiple', disabled: true },
        { label: 'Cities & Zones', icon: 'mdi-map-marker-multiple-outline', disabled: true },
        { label: 'Live Map', icon: 'mdi-map-outline', disabled: true },
        { label: 'Support', to: '/adminSupport', icon: 'mdi-headset' },
        { label: 'Finance', to: '/adminBilling', icon: 'mdi-wallet-outline' },
        { label: 'Reports', icon: 'mdi-chart-box-outline', disabled: true },
        { label: 'Settings', icon: 'mdi-cog-outline', disabled: true },
        { label: 'Audit Log', icon: 'mdi-history', disabled: true },
        { label: 'Database Tools', to: '/adminDB', icon: 'mdi-database-cog-outline' }
      ]
    }
  },
  computed: {
    isLoginPage() {
      return this.$route.path === '/adminLogin'
    }
  },
  async created() {
    if (!supabase) return
    try {
      const result = await supabase.auth.getUser()
      if (result.data && result.data.user) this.userEmail = result.data.user.email || ''
    } catch (error) {
      this.userEmail = ''
    }
    const subscription = supabase.auth.onAuthStateChange((event, session) => {
      this.userEmail = session && session.user ? (session.user.email || '') : ''
      if (event === 'SIGNED_OUT' && this.$route.path !== '/adminLogin') {
        this.$router.replace('/adminLogin')
      }
    })
    this.authSubscription = subscription.data.subscription
  },
  beforeDestroy() {
    if (this.authSubscription) this.authSubscription.unsubscribe()
  },
  methods: {
    async signOut() {
      if (supabase) await supabase.auth.signOut()
      this.userEmail = ''
      this.$router.replace('/adminLogin')
    }
  }
}
</script>

<style>
html, body, #app {
  min-height: 100%;
  width: 100%;
  margin: 0;
  background: #080e1c;
}
body {
  overflow-x: hidden;
}
.moonride-shell {
  background: #080e1c !important;
}
.admin-background {
  min-height: 100vh;
  background:
    radial-gradient(circle at 78% 0%, rgba(37, 99, 235, .09), transparent 28%),
    #080e1c;
  color: #f4f6ff;
}
.login-background {
  min-height: 100vh;
  background: #080e1c;
}
.moonride-sidebar {
  border-right: 1px solid rgba(107, 135, 190, .20) !important;
}
.sidebar-divider {
  border-color: rgba(107, 135, 190, .18) !important;
  margin: 0 16px 14px;
}
.sidebar-section-label {
  color: #7384a3;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.8px;
  padding: 4px 22px 9px;
}
.sidebar-menu {
  padding: 0 11px;
}
.sidebar-item {
  min-height: 43px;
  margin: 3px 0;
  border-radius: 10px;
  color: #d4deef !important;
}
.sidebar-item .v-icon {
  color: #9cacc9 !important;
}
.sidebar-item-active {
  background: linear-gradient(90deg, rgba(245, 189, 24, .22), rgba(245, 189, 24, .06)) !important;
  border-left: 3px solid #f5bd18;
  color: #fff !important;
}
.sidebar-item-active .v-icon,
.sidebar-item-active .v-list-item__title {
  color: #ffd34d !important;
}
.sidebar-item.v-list-item--disabled {
  opacity: .43;
}
.coming-soon {
  color: #8b9ab5;
  font-size: 8px;
  font-weight: 800;
  letter-spacing: .7px;
}
.sidebar-account {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px 12px;
  border-top: 1px solid rgba(107, 135, 190, .18);
}
.account-avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #172746;
}
.account-copy { min-width: 0; }
.account-title { color: #eef3ff; font-size: 12px; font-weight: 700; }
.account-email {
  color: #8595b2;
  font-size: 10px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 175px;
}
.sidebar-signout {
  color: #aab8d1 !important;
  border-top: 1px solid rgba(107, 135, 190, .12);
  border-radius: 0 !important;
  height: 44px !important;
}
.moonride-topbar {
  background: rgba(7, 13, 27, .97) !important;
  border-bottom: 1px solid rgba(107, 135, 190, .18);
}
.topbar-title {
  color: #eef3ff;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: .7px;
}
.topbar-title small {
  color: #8292af;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 1px;
}
.topbar-secure {
  font-size: 9px !important;
  letter-spacing: 1px;
}
@media (max-width: 600px) {
  .topbar-title { font-size: 11px; }
  .topbar-title small { display: none; }
  .topbar-secure { display: none; }
}
</style>