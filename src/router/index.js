import Vue from 'vue'
import Router from 'vue-router'
import supabase from '@/services/supabase'
import DriverAuth from '@/components/driver/DriverAuth'
import DriverShell from '@/components/driver/DriverShell'
import DriverHome from '@/components/driver/DriverHome'
import DriverOrders from '@/components/driver/DriverOrders'
import DriverProfile from '@/components/driver/DriverProfile'

Vue.use(Router)

const router = new Router({
  mode: 'hash',
  routes: [
    { path: '/auth', name: 'driver-auth', component: DriverAuth },
    {
      path: '/',
      component: DriverShell,
      meta: { requiresDriver: true },
      children: [
        { path: '', name: 'driver-home', component: DriverHome },
        { path: 'orders', name: 'driver-orders', component: DriverOrders },
        { path: 'profile', name: 'driver-profile', component: DriverProfile }
      ]
    },
    { path: '*', redirect: '/' }
  ]
})

router.beforeEach(async (to, from, next) => {
  const protectedRoute = to.matched.some(record => record.meta.requiresDriver)
  if (!protectedRoute) {
    if (to.name === 'driver-auth' && supabase) {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        if (session) return next({ name: 'driver-home' })
      } catch (error) {}
    }
    return next()
  }
  if (!supabase) return next({ name: 'driver-auth' })
  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) return next({ name: 'driver-auth' })
    const { data: profile, error: profileError } = await supabase
      .from('profiles').select('role').eq('id', user.id).maybeSingle()
    if (profileError || !profile || profile.role !== 'driver') {
      await supabase.auth.signOut()
      return next({ name: 'driver-auth' })
    }
    return next()
  } catch (error) {
    return next({ name: 'driver-auth' })
  }
})

export default router
