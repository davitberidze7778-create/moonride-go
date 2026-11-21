import Vue from 'vue'
import Router from 'vue-router'
import supabase from '@/services/supabase'
import PassengerAuth from '@/components/passenger/PassengerAuth'
import PassengerShell from '@/components/passenger/PassengerShell'
import PassengerHome from '@/components/passenger/PassengerHome'
import PassengerOrders from '@/components/passenger/PassengerOrders'
import PassengerProfile from '@/components/passenger/PassengerProfile'

Vue.use(Router)

const router = new Router({
  mode: 'hash',
  routes: [
    { path: '/auth', name: 'auth', component: PassengerAuth },
    {
      path: '/',
      component: PassengerShell,
      meta: { requiresPassenger: true },
      children: [
        { path: '', name: 'home', component: PassengerHome },
        { path: 'orders', name: 'orders', component: PassengerOrders },
        { path: 'profile', name: 'profile', component: PassengerProfile }
      ]
    },
    { path: '*', redirect: '/' }
  ]
})

router.beforeEach(async (to, from, next) => {
  const protectedRoute = to.matched.some(record => record.meta.requiresPassenger)
  if (!protectedRoute) {
    if (to.name === 'auth' && supabase) {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        if (session) return next({ name: 'home' })
      } catch (e) { /* Stay on the authentication screen. */ }
    }
    return next()
  }

  if (!supabase) return next({ name: 'auth' })

  try {
    const { data: { session }, error: sessionError } = await supabase.auth.getSession()
    if (sessionError || !session || !session.user) return next({ name: 'auth' })

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role,account_status')
      .eq('id', session.user.id)
      .maybeSingle()

    if (profileError || !profile || profile.role !== 'passenger' || profile.account_status !== 'active') {
      await supabase.auth.signOut()
      return next({ name: 'auth' })
    }
    return next()
  } catch (error) {
    return next({ name: 'auth' })
  }
})

export default router
