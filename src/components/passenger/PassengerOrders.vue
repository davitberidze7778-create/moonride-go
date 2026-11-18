<template>
  <div class="orders-page">
    <div class="page-heading"><div class="eyebrow">G_o · PASSENGER</div><h1>შეკვეთები</h1><p>შენახული ფასის შეთავაზებები</p></div>
    <v-alert dense text type="info" class="orders-note">ეს სია აჩვენებს Supabase-ში შენახულ ფასის შეთავაზებებს (ride_quotes). დასრულებული მგზავრობების სრული ისტორია გამოჩნდება შეკვეთის სისტემის მიერთების შემდეგ.</v-alert>
    <div v-if="loading" class="state-box"><v-progress-circular indeterminate color="#f5bd18" size="30" /><p>მონაცემები იტვირთება...</p></div>
    <div v-else-if="error" class="state-box error-text">{{ error }}</div>
    <div v-else-if="quotes.length === 0" class="empty-state">
      <v-icon size="48" color="#6f809d">mdi-receipt-text-clock-outline</v-icon>
      <h2>ჯერ შეთავაზებები არ გაქვს</h2>
      <p>შენი სამომავლო ფასის შეთავაზებები აქ გამოჩნდება.</p>
      <v-btn text color="#f5bd18" @click="$router.push({ name: 'home' })">მთავარზე დაბრუნება</v-btn>
    </div>
    <div v-else class="quote-list">
      <v-card v-for="quote in quotes" :key="quote.id" class="quote-card" elevation="0">
        <div class="quote-top"><span class="quote-id">#{{ quote.id.slice(0, 8).toUpperCase() }}</span><span class="quote-status">{{ statusLabel(quote.status) }}</span></div>
        <div class="quote-price">{{ formatPrice(quote.selected_fare, quote.currency_code) }}</div>
        <div class="quote-meta">
          <span><v-icon x-small>mdi-map-marker-distance</v-icon> {{ quote.total_distance_km || '—' }} კმ</span>
          <span><v-icon x-small>mdi-clock-outline</v-icon> {{ quote.total_duration_minutes || '—' }} წთ</span>
        </div>
        <div class="quote-date">{{ formatDate(quote.created_at) }}</div>
      </v-card>
    </div>
    <v-btn v-if="!loading" block outlined color="#f5bd18" class="refresh-button" @click="loadQuotes">განახლება</v-btn>
  </div>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'PassengerOrders',
  data() { return { quotes: [], loading: true, error: '' } },
  mounted() { this.loadQuotes() },
  methods: {
    async loadQuotes() {
      this.loading = true
      this.error = ''
      try {
        if (!supabase) throw new Error('Supabase კავშირი არ არის გამართული.')
        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) throw new Error('შესვლის სესია ვერ მოიძებნა.')
        const { data, error } = await supabase
          .from('ride_quotes')
          .select('id,status,selected_fare,currency_code,total_distance_km,total_duration_minutes,created_at,expires_at,quote_source')
          .eq('passenger_id', user.id)
          .order('created_at', { ascending: false })
          .limit(30)
        if (error) throw error
        this.quotes = data || []
      } catch (error) {
        this.error = error.message || 'მონაცემების ჩატვირთვა ვერ მოხერხდა.'
      } finally {
        this.loading = false
      }
    },
    statusLabel(status) {
      const labels = { pending: 'მოლოდინში', priced: 'ფასი დათვლილია', confirmed: 'დადასტურებული შეთავაზება', expired: 'ვადაგასული', cancelled: 'გაუქმებული' }
      return labels[status] || status || '—'
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
.orders-page { color: #e3e9f5; }
.page-heading .eyebrow { color: #f5bd18; font-size: 9px; font-weight: 800; letter-spacing: 2px; }
.page-heading h1 { color: #f4f6fb; margin: 7px 0 4px; font-size: 25px; font-weight: 800; }
.page-heading p { color: #8796b1; margin: 0 0 16px; font-size: 12px; }
.orders-note { font-size: 11px; line-height: 1.55; }
.state-box, .empty-state { min-height: 210px; display: flex; flex-direction: column; justify-content: center; align-items: center; color: #8796b1; text-align: center; gap: 12px; font-size: 12px; }
.empty-state h2 { color: #e3e9f5; font-size: 15px; margin: 0; }
.empty-state p { margin: 0; }
.error-text { color: #ff9e9e; }
.quote-list { display: flex; flex-direction: column; gap: 11px; margin-top: 15px; }
.quote-card { padding: 15px; border-radius: 14px !important; background: #111b2e !important; border: 1px solid rgba(132,154,192,.17) !important; color: #e3e9f5; }
.quote-top { display: flex; justify-content: space-between; gap: 10px; }
.quote-id { color: #8494ad; font-size: 10px; font-weight: 800; letter-spacing: 1px; }
.quote-status { color: #f5ca55; font-size: 10px; }
.quote-price { margin: 12px 0 8px; font-size: 23px; font-weight: 900; color: #f4f6fb; }
.quote-meta { display: flex; gap: 16px; color: #9aa8be; font-size: 11px; }
.quote-meta .v-icon { color: #f5bd18; margin-right: 3px; }
.quote-date { color: #697b96; font-size: 10px; margin-top: 10px; }
.refresh-button { margin-top: 17px; border-radius: 10px; }
</style>
