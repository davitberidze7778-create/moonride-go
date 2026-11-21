<template>
  <div class="orders-page">
    <div class="page-heading"><div class="eyebrow">MOONRIDE GO · PASSENGER</div><h1>შეკვეთები</h1><p>აქტიური მგზავრობები და შეთავაზებების ისტორია</p></div>
    <div v-if="loading" class="state-box"><v-progress-circular indeterminate color="#2F80FF" size="30" /><p>მონაცემები იტვირთება...</p></div>
    <div v-else-if="error" class="state-box error-text">{{ error }}</div>
    <template v-else>
      <section v-if="rides.length" class="orders-section">
        <div class="section-title">მგზავრობები</div>
        <v-card v-for="ride in rides" :key="ride.id" class="ride-card" elevation="0">
          <div class="quote-top"><span class="quote-id">#{{ ride.id.slice(0, 8).toUpperCase() }}</span><span class="quote-status">{{ rideStatus(ride.status) }}</span></div>
          <div class="ride-route">
            <div class="route-line"><span class="origin-dot"></span><span>{{ ride.pickup_address || 'საწყისი მისამართი' }}</span></div>
            <div class="route-line"><span class="destination-dot"></span><span>{{ ride.dropoff_address || 'დანიშნულების მისამართი' }}</span></div>
          </div>
          <div class="ride-bottom">
            <strong>{{ formatPrice(ride.fare_amount, ride.currency_code) }}</strong>
            <span>{{ categoryLabel(ride.category_code) }} · {{ paymentLabel(ride.payment_method) }}</span>
          </div>
          <div class="quote-date">{{ formatDate(ride.requested_at) }}</div>
        </v-card>
      </section>

      <section v-if="quotes.length" class="orders-section">
        <div class="section-title">ფასის შეთავაზებები</div>
        <v-card v-for="quote in quotes" :key="quote.id" class="quote-card" elevation="0">
          <div class="quote-top"><span class="quote-id">#{{ quote.id.slice(0, 8).toUpperCase() }}</span><span class="quote-status">{{ statusLabel(quote.status) }}</span></div>
          <div class="quote-price">{{ formatPrice(quote.selected_fare, quote.currency_code) }}</div>
          <div class="quote-meta">
            <span><v-icon x-small>mdi-map-marker-distance</v-icon> {{ quote.total_distance_km || '—' }} კმ</span>
            <span><v-icon x-small>mdi-clock-outline</v-icon> {{ quote.total_duration_minutes || '—' }} წთ</span>
          </div>
          <div class="quote-date">{{ formatDate(quote.created_at) }}</div>
        </v-card>
      </section>

      <div v-if="!rides.length && !quotes.length" class="empty-state">
        <v-icon size="48" color="#6f809d">mdi-receipt-text-clock-outline</v-icon>
        <h2>ჯერ შეკვეთები არ გაქვს</h2>
        <p>როცა მარშრუტს გამოთვლი ან მგზავრობას შეუკვეთავ, ჩანაწერი აქ გამოჩნდება.</p>
        <v-btn text color="#8BCBFF" @click="$router.push({ name: 'home' })">მარშრუტის დაგეგმვა</v-btn>
      </div>
    </template>
    <v-btn v-if="!loading" block outlined color="#2F80FF" class="refresh-button" :loading="refreshing" @click="loadOrders">განახლება</v-btn>
  </div>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'PassengerOrders',
  data() { return { rides: [], quotes: [], loading: true, refreshing: false, error: '' } },
  mounted() { this.loadOrders() },
  methods: {
    async loadOrders() {
      this.loading = !this.rides.length && !this.quotes.length
      this.refreshing = !this.loading
      this.error = ''
      try {
        if (!supabase) throw new Error('Supabase კავშირი არ არის გამართული.')
        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) throw new Error('შესვლის სესია ვერ მოიძებნა.')
        const [ridesResult, quotesResult] = await Promise.all([
          supabase.from('go_rides')
            .select('id,category_code,pickup_address,dropoff_address,fare_amount,currency_code,payment_method,payment_status,status,requested_at,driver_user_id')
            .eq('passenger_id', user.id)
            .order('requested_at', { ascending: false })
            .limit(30),
          supabase.from('ride_quotes')
            .select('id,status,selected_fare,currency_code,total_distance_km,total_duration_minutes,created_at,expires_at,quote_source')
            .eq('passenger_id', user.id)
            .order('created_at', { ascending: false })
            .limit(30)
        ])
        if (ridesResult.error) throw ridesResult.error
        if (quotesResult.error) throw quotesResult.error
        this.rides = ridesResult.data || []
        this.quotes = quotesResult.data || []
      } catch (error) {
        this.error = error.message || 'მონაცემების ჩატვირთვა ვერ მოხერხდა.'
      } finally {
        this.loading = false
        this.refreshing = false
      }
    },
    rideStatus(status) {
      const labels = {
        requested: 'მიღებულია', dispatching: 'მძღოლის ძიება', accepted: 'მძღოლი დათანხმდა',
        driver_arriving: 'მძღოლი გზაშია', arrived: 'მძღოლი ადგილზეა',
        in_progress: 'მგზავრობა მიმდინარეობს', completed: 'დასრულებული',
        cancelled: 'გაუქმებული', no_driver: 'მძღოლი ვერ მოიძებნა'
      }
      return labels[status] || status || '—'
    },
    statusLabel(status) {
      const labels = { pending: 'მოლოდინში', priced: 'ფასი დათვლილია', confirmed: 'დადასტურებული', expired: 'ვადაგასული', cancelled: 'გაუქმებული' }
      return labels[status] || status || '—'
    },
    categoryLabel(code) {
      const labels = {
        ECONOM_GO: 'ECONOM GO', ECONOM_PLUS_GO: 'ECONOM+ GO',
        COMFORT_GO: 'COMFORT GO', COMFORT_PLUS_GO: 'COMFORT+ GO',
        XL_GO: 'XL GO', PREMIUM_GO: 'PREMIUM GO'
      }
      return labels[code] || code || '—'
    },
    paymentLabel(method) {
      return method === 'cash' ? 'ნაღდი' : (method || '—')
    },
    formatPrice(value, currency) {
      if (value === null || value === undefined) return 'ფასი ჯერ არ არის'
      return Number(value).toFixed(2) + ' ' + (currency || 'GEL')
    },
    formatDate(value) {
      if (!value) return 'თარიღი უცნობია'
      return new Date(value).toLocaleString('ka-GE', { dateStyle: 'medium', timeStyle: 'short' })
    }
  }
}
</script>

<style scoped>
.orders-page { color:#e3e9f5; }
.page-heading .eyebrow { color:#48B7FF; font-size:9px; font-weight:800; letter-spacing:2px; }
.page-heading h1 { color:#f4f6fb; margin:7px 0 4px; font-size:25px; font-weight:800; }
.page-heading p { color:#8796b1; margin:0 0 17px; font-size:12px; }
.orders-section { margin:16px 0 20px; }
.section-title { margin:0 0 9px; color:#eef4ff; font-size:13px; font-weight:850; }
.state-box,.empty-state { min-height:210px; display:flex; flex-direction:column; justify-content:center; align-items:center; color:#8796b1; text-align:center; gap:12px; font-size:12px; }
.empty-state h2 { color:#e3e9f5; font-size:15px; margin:0; }
.empty-state p { margin:0; max-width:270px; line-height:1.55; }
.error-text { color:#ff9e9e; }
.ride-card,.quote-card { margin:9px 0; padding:15px; border-radius:14px !important; background:#102544 !important; border:1px solid rgba(82,145,225,.17) !important; color:#e3e9f5; }
.quote-top { display:flex; justify-content:space-between; gap:10px; }
.quote-id { color:#8494ad; font-size:10px; font-weight:800; letter-spacing:1px; }
.quote-status { color:#8BCBFF; font-size:10px; text-align:right; }
.ride-route { margin:13px 0 12px; display:flex; flex-direction:column; gap:10px; }
.route-line { display:flex; align-items:flex-start; gap:10px; color:#dce8f8; font-size:11px; line-height:1.5; }
.origin-dot { flex:0 0 10px; width:10px; height:10px; margin-top:3px; border:3px solid #48B7FF; border-radius:50%; }
.destination-dot { flex:0 0 10px; width:10px; height:10px; margin-top:3px; border:2px solid #eaf3ff; border-radius:2px; }
.ride-bottom { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:7px; padding-top:10px; border-top:1px solid rgba(149,178,218,.13); }
.ride-bottom strong { color:#f4f8ff; font-size:17px; }
.ride-bottom span { color:#8ca2c3; font-size:10px; }
.quote-price { margin:12px 0 8px; font-size:23px; font-weight:900; color:#f4f6fb; }
.quote-meta { display:flex; gap:16px; color:#9aa8be; font-size:11px; }
.quote-meta .v-icon { color:#48B7FF; margin-right:3px; }
.quote-date { color:#697b96; font-size:10px; margin-top:10px; }
.refresh-button { margin-top:17px; border-radius:10px; }
</style>
