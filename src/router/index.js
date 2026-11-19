import Vue from 'vue'
import Router from 'vue-router'
import supabase from '@/services/supabase'
import AdminLogin from '@/components/AdminLogin'
import AdminDashboard from '@/components/AdminDashboard'
import AdminDBManagement from '@/components/AdminDBManagement'
import AdminActivity from '@/components/AdminActivity'
import AdminAllClients from '@/components/AdminAllClients'
import AdminAllDrivers from '@/components/AdminAllDrivers'
import AdminVehicles from '@/components/AdminVehicles'
import AdminBilling from '@/components/AdminBilling'
import AdminSupport from '@/components/AdminSupport'
import AdminSystemControls from '@/components/AdminSystemControls'

Vue.use(Router)

// This APK is the administration app only. Passenger and driver routes stay
// in their separate applications and are intentionally not exposed here.
const routes = [
  { path: '/', redirect: '/adminLogin' },
  { path: '/adminLogin', component: AdminLogin, props: true },
  { path: '/admin', component: AdminDashboard, meta: { requiresMasterAdmin: true } },
  { path: '/adminDB', component: AdminDBManagement, meta: { requiresMasterAdmin: true } },
  { path: '/adminAllClients', component: AdminAllClients, meta: { requiresMasterAdmin: true } },
  { path: '/adminAllDrivers', component: AdminAllDrivers, meta: { requiresMasterAdmin: true } },
  { path: '/adminVehicles', component: AdminVehicles, meta: { requiresMasterAdmin: true } },
  { path: '/adminActivity', component: AdminActivity, meta: { requiresMasterAdmin: true } },
  { path: '/adminBilling', component: AdminBilling, meta: { requiresMasterAdmin: true } },
  { path: '/adminSupport', component: AdminSupport, meta: { requiresMasterAdmin: true } },
  { path: '/adminControls', component: AdminSystemControls, meta: { requiresMasterAdmin: true } },
  { path: '*', redirect: '/admin' }
]

const router = new Router({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

router.beforeEach(async (to, from, next) => {
  const requiresMasterAdmin = to.matched.some(record => record.meta.requiresMasterAdmin)

  if (!requiresMasterAdmin) {
    next()
    return
  }

  if (!supabase) {
    next('/adminLogin')
    return
  }

  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      next('/adminLogin')
      return
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle()

    if (profileError || !profile || profile.role !== 'master_admin') {
      await supabase.auth.signOut()
      next('/adminLogin')
      return
    }

    next()
  } catch (error) {
    next('/adminLogin')
  }
})

export default router
