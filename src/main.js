import Vue from 'vue'
import App from '@/App.vue'
import '@/registerServiceWorker'
import router from '@/router'
import store from '@/store'
import vuetify from '@/plugins/vuetify'

// MASTER ADMIN uses Supabase. Legacy Firebase/VueFire and passenger/driver
// mapping plugins are intentionally not initialized in this APK.
Vue.config.productionTip = false

new Vue({
  router,
  store,
  vuetify,
  render: h => h(App)
}).$mount('#app')
