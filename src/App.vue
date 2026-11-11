<template>
  <v-app dark>
    <v-app-bar v-if="!isLoginPage" app color="#101827" dark>
      <v-app-bar-nav-icon
        v-if="$vuetify.breakpoint.mobile"
        aria-label="Open navigation menu"
        @click.stop="mobileDrawer = !mobileDrawer"
      />
      <v-toolbar-title class="font-weight-bold text-truncate" style="font-size: 16px;">
        MOONRIDE GO <span class="amber--text">/ MASTER ADMIN</span>
      </v-toolbar-title>
      <v-spacer></v-spacer>
      <v-btn small text v-if="userEmail" @click="signOut">Sign out</v-btn>
    </v-app-bar>

    <v-navigation-drawer
      v-if="!isLoginPage"
      v-model="mobileDrawer"
      app
      dark
      color="#101827"
      width="245"
      :permanent="!$vuetify.breakpoint.mobile"
      :temporary="$vuetify.breakpoint.mobile"
    >
      <v-list dense nav>
        <v-list-item
          v-for="item in adminLinks"
          :key="item.to"
          :to="item.to"
          link
          @click="mobileDrawer = false"
        >
          <v-list-item-content>
            <v-list-item-title>{{ item.label }}</v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>
      <template v-slot:append>
        <div class="pa-3 caption grey--text" v-if="userEmail">{{ userEmail }}</div>
      </template>
    </v-navigation-drawer>

    <v-main :class="isLoginPage ? 'login-background' : 'admin-background'">
      <router-view />
    </v-main>
  </v-app>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  data() {
    return {
      userEmail: '',
      mobileDrawer: false,
      adminLinks: [
        { label: 'Dashboard', to: '/admin' },
        { label: 'Passengers', to: '/adminAllClients' },
        { label: 'Drivers', to: '/adminAllDrivers' },
        { label: 'Activity / Orders', to: '/adminActivity' },
        { label: 'Finance', to: '/adminBilling' },
        { label: 'Database tools', to: '/adminDB' },
        { label: 'Support', to: '/adminSupport' }
      ],
      authSubscription: null
    }
  },
  computed: {
    isLoginPage() {
      return this.$route.path === '/adminLogin'
    }
  },
  async created() {
    if (!supabase) return
    const result = await supabase.auth.getUser()
    if (result.data && result.data.user) this.userEmail = result.data.user.email || ''
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
  background: #080e18;
}
body {
  overflow-x: hidden;
}
.admin-background {
  min-height: 100vh;
  background: #080e18;
  color: #f4f6f8;
}
.login-background {
  min-height: 100vh;
  background: #080e18;
}
</style>
