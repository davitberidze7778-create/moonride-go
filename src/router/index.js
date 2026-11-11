import Vue from 'vue'
import Router from 'vue-router'
import supabase from '@/services/supabase'
import Home from '@/components/Home'
import Login from '@/components/Login'
import AdminLogin from '@/components/AdminLogin'
import AdminDashboard from '@/components/AdminDashboard'
import AdminDBManagement from '@/components/AdminDBManagement'
import AdminActivity from '@/components/AdminActivity'
import AdminAllClients from '@/components/AdminAllClients'
import AdminAllDrivers from '@/components/AdminAllDrivers'
import AdminBilling from '@/components/AdminBilling'
import AdminSupport from '@/components/AdminSupport'
import ClientLogin from '@/components/ClientLogin'
import ClientRegister from '@/components/ClientRegister'
import ClientDashboard from '@/components/ClientDashboard'
import ClientProfile from '@/components/ClientProfile'
import ClientPickupNew from '@/components/ClientPickupNew'
import ClientPickupEdit from '@/components/ClientPickupEdit'
import ClientSupport from '@/components/ClientSupport'
import DriverLogin from '@/components/DriverLogin'
import DriverRegister from '@/components/DriverRegister'
import DriverDashboard from '@/components/DriverDashboard'
import DriverProfile from '@/components/DriverProfile'
import DriverSupport from '@/components/DriverSupport'
import TripFuture from '@/components/TripFuture'
import TripHistory from '@/components/TripHistory'
import TripNext from '@/components/TripNext'
import MapPickupNew from '@/components/MapPickupNew'

Vue.use(Router)

const routes = [
  {
    path: '/',
    name: 'Home',
    component: Home
  },
  { path: '/map', component: MapPickupNew },
  { path: '/login', component: Login, props: true },
  { path: '/clientLogin', component: ClientLogin, props: true },
  { path: '/clientRegister', component: ClientRegister, props: true },
  { path: '/clientDashboard', component: ClientDashboard, meta: {
    requiresAuth: false
  } },
  { path: '/clientProfile', component: ClientProfile, meta: {
    requiresAuth: false
  } },
  { path: '/newPickup', component: ClientPickupNew, meta: {
    requiresAuth: false
  } },
  { path: '/editPickup', component: ClientPickupEdit, meta: {
    requiresAuth: false
  } },
  { path: '/tripFuture', component: TripFuture, meta: {
    requiresAuth: false
  } },
  { path: '/tripHistory', component: TripHistory, meta: {
    requiresAuth: false
  } },
  { path: '/tripNext', component: TripNext, meta: {
    requiresAuth: false
  } },
  { path: '/clientSupport', component: ClientSupport },
  { path: '/driverLogin', component: DriverLogin, props: true },
  { path: '/driverRegister', component: DriverRegister, props: true },
  { path: '/driverDashboard', component: DriverDashboard, meta: {
    requiresAuth: false
  } },
  { path: '/driverProfile', component: DriverProfile, meta: {
    requiresAuth: false
  } },
  { path: '/driverSupport', component: DriverSupport },
  { path: '/adminLogin', component: AdminLogin, props: true },
  { path: '/admin', component: AdminDashboard, meta: { requiresMasterAdmin: true } },
  { path: '/adminDB', component: AdminDBManagement, meta: { requiresMasterAdmin: true } },
  { path: '/adminAllClients', component: AdminAllClients, meta: { requiresMasterAdmin: true } },
  { path: '/adminAllDrivers', component: AdminAllDrivers, meta: { requiresMasterAdmin: true } },
  { path: '/adminActivity', component: AdminActivity, meta: { requiresMasterAdmin: true } },
  { path: '/adminBilling', component: AdminBilling, meta: { requiresMasterAdmin: true } },
  { path: '/adminSupport', component: AdminSupport, meta: { requiresMasterAdmin: true } }
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