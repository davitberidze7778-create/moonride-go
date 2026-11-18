<template>
  <div class="home-page">
    <div class="welcome-row">
      <div><div class="eyebrow">G_o</div><h1>გამარჯობა{{ firstName ? ', ' + firstName : '' }}!</h1><p>სად წავიდეთ დღეს?</p></div>
      <div class="welcome-pin"><v-icon color="#f5bd18" size="27">mdi-map-marker</v-icon></div>
    </div>

    <v-card class="booking-card" elevation="0">
      <div class="booking-heading"><v-icon color="#f5bd18">mdi-taxi</v-icon><span>მგზავრობის დაგეგმვა</span></div>
      <div class="location-row">
        <div class="route-rail"><span class="pickup-dot"></span><i></i><span class="drop-dot"></span></div>
        <div class="location-fields">
          <div class="location-field">
            <label>საიდან</label>
            <div class="location-value">{{ pickupText || 'მდებარეობა ჯერ არ მიგვიღია' }}</div>
          </div>
          <div class="field-divider"></div>
          <div class="location-field">
            <label>სად</label>
            <div class="location-value muted">მისამართის ძებნა 2GIS-ის მიერთების შემდეგ</div>
          </div>
        </div>
      </div>
      <v-btn block outlined color="#f5bd18" class="gps-button" :loading="locating" :disabled="locating" @click="useMyLocation">
        <v-icon left>mdi-crosshairs-gps</v-icon> ჩემი მდებარეობის გამოყენება
      </v-btn>
      <v-alert v-if="locationMessage" dense text :type="locationError ? 'warning' : 'success'" class="location-alert">{{ locationMessage }}</v-alert>
    </v-card>

    <v-card class="notice-card" elevation="0">
      <div class="notice-icon"><v-icon color="#f5bd18" size="28">mdi-map-search-outline</v-icon></div>
      <div class="notice-content">
        <h2>რუკა და მგზავრობის შეკვეთა</h2>
        <p>ანგარიში და პროფილი Supabase-ს უკავშირდება. რეალური მარშრუტის ძებნისა და ტაქსის გამოძახების ჩასართავად საჭიროა 2GIS რუკის გასაღები და G_o შეკვეთის/მძღოლის მინიჭების backend.</p>
        <div class="notice-status"><span></span> შემდეგი ინტეგრაციის ეტაპი</div>
      </div>
    </v-card>

    <div class="quick-title">აპლიკაციის განყოფილებები</div>
    <div class="quick-grid">
      <button class="quick-tile" @click="$router.push({ name: 'orders' })"><v-icon>mdi-receipt-text-outline</v-icon><span>ჩემი შეკვეთები</span><small>შეთავაზებების ისტორია</small></button>
      <button class="quick-tile" @click="$router.push({ name: 'profile' })"><v-icon>mdi-account-cog-outline</v-icon><span>ჩემი პროფილი</span><small>პირადი მონაცემები</small></button>
    </div>
  </div>
</template>

<script>
import { Geolocation } from '@capacitor/geolocation'
import supabase from '@/services/supabase'

export default {
  name: 'PassengerHome',
  data() {
    return {
      firstName: '',
      pickupText: '',
      locating: false,
      locationMessage: '',
      locationError: false
    }
  },
  async mounted() {
    if (!supabase) return
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    const { data } = await supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
    if (data && data.full_name) this.firstName = data.full_name.trim().split(/\s+/)[0]
  },
  methods: {
    async useMyLocation() {
      this.locationMessage = ''
      this.locationError = false
      this.locating = true
      try {
        let permissions = await Geolocation.checkPermissions()
        if (permissions.location !== 'granted' && permissions.coarseLocation !== 'granted') {
          permissions = await Geolocation.requestPermissions()
        }
        if (permissions.location !== 'granted' && permissions.coarseLocation !== 'granted') {
          throw new Error('მდებარეობაზე წვდომა არ არის ნებადართული. ჩართე Location ნებართვა.')
        }
        const position = await Geolocation.getCurrentPosition({
          enableHighAccuracy: true,
          timeout: 20000,
          maximumAge: 15000
        })
        this.pickupText = position.coords.latitude.toFixed(6) + ', ' + position.coords.longitude.toFixed(6)
        this.locationMessage = 'GPS მდებარეობა მიღებულია. მისამართის ამოცნობა 2GIS-ის მიერთების შემდეგ დაემატება.'
      } catch (error) {
        this.locationError = true
        this.locationMessage = error && error.message ? error.message : 'მდებარეობის მიღება ვერ მოხერხდა. შეამოწმე მოწყობილობის Location პარამეტრები.'
      } finally {
        this.locating = false
      }
    }
  }
}
</script>

<style scoped>
.home-page { color: #e3e9f5; }
.welcome-row { display: flex; align-items: center; justify-content: space-between; margin: 5px 0 22px; }
.eyebrow { color: #f5bd18; font-size: 9px; font-weight: 800; letter-spacing: 2px; }
.welcome-row h1 { margin: 7px 0 3px; font-size: 24px; color: #f4f6fb; font-weight: 800; }
.welcome-row p { margin: 0; font-size: 13px; color: #8796b1; }
.welcome-pin { width: 48px; height: 48px; border-radius: 15px; display: flex; align-items: center; justify-content: center; background: #182640; border: 1px solid rgba(245,189,24,.22); }
.booking-card, .notice-card { padding: 18px; border-radius: 17px !important; border: 1px solid rgba(132,154,192,.18) !important; background: #111b2e !important; color: #e3e9f5; }
.booking-heading { display: flex; align-items: center; gap: 10px; font-size: 15px; font-weight: 800; margin-bottom: 18px; }
.location-row { display: flex; gap: 13px; margin: 0 0 17px; }
.route-rail { width: 13px; display: flex; flex-direction: column; align-items: center; padding: 7px 0; }
.pickup-dot { width: 9px; height: 9px; border: 2px solid #f5bd18; border-radius: 50%; }
.drop-dot { width: 9px; height: 9px; background: #e3e9f5; border-radius: 2px; }
.route-rail i { width: 1px; flex: 1; min-height: 24px; border-left: 1px dashed #6d7d98; }
.location-fields { flex: 1; min-width: 0; }
.location-field { padding: 2px 0 12px; }
.location-field label { display: block; color: #8292af; font-size: 10px; margin-bottom: 5px; }
.location-value { color: #e3e9f5; font-size: 12px; }
.location-value.muted { color: #687994; }
.field-divider { border-top: 1px solid rgba(132,154,192,.15); margin-bottom: 12px; }
.gps-button { font-size: 11px !important; border-radius: 10px; }
.location-alert { margin-top: 13px; font-size: 11px; }
.notice-card { display: flex; gap: 14px; margin-top: 17px; background: linear-gradient(135deg,#17243b,#101a2c) !important; }
.notice-icon { flex: 0 0 44px; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; border-radius: 13px; background: rgba(245,189,24,.1); }
.notice-content h2 { margin: 0 0 8px; font-size: 14px; color: #f3f6fc; }
.notice-content p { margin: 0; color: #9ba9bf; font-size: 11px; line-height: 1.6; }
.notice-status { display: flex; align-items: center; gap: 7px; color: #f4ca51; font-size: 10px; font-weight: 700; margin-top: 12px; }
.notice-status span { width: 6px; height: 6px; background: #f5bd18; border-radius: 50%; }
.quick-title { margin: 22px 0 11px; color: #dfe6f3; font-size: 13px; font-weight: 800; }
.quick-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 11px; }
.quick-tile { display: flex; flex-direction: column; align-items: flex-start; gap: 7px; padding: 15px; border-radius: 14px; border: 1px solid rgba(132,154,192,.18); background: #111b2e; color: #e3e9f5; text-align: left; }
.quick-tile .v-icon { color: #f5bd18; }
.quick-tile span { font-size: 12px; font-weight: 800; }
.quick-tile small { color: #8292af; font-size: 10px; }
</style>
