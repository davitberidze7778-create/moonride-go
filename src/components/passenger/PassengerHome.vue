<template>
  <div class="home-page">
    <div class="welcome-row">
      <div>
        <h1>გამარჯობა{{ firstName ? ', ' + firstName : '' }}!</h1>
        <p>სად წავიდეთ დღეს?</p>
      </div>
      <button class="sos-mini" @click="callEmergency"><v-icon color="#fff" size="20">mdi-phone-alert</v-icon><span>SOS</span></button>
    </div>

    <TomTomMap ref="tomtomMap" />

    <v-card class="booking-card" elevation="0">
      <div class="booking-heading"><v-icon color="#742BFF">mdi-taxi</v-icon><span>მგზავრობის დაგეგმვა</span></div>
      <div class="location-field">
        <label>საიდან</label>
        <div class="input-line">
          <v-icon color="#742BFF" size="19">mdi-map-marker</v-icon>
          <input v-model.trim="pickupText" type="text" placeholder="აირჩიე საწყისი მისამართი" />
          <button class="gps-mini" :disabled="locating" @click="useMyLocation"><v-icon small>mdi-crosshairs-gps</v-icon></button>
        </div>
      </div>
      <div class="location-field">
        <label>სად</label>
        <div class="input-line">
          <v-icon color="#e3e9f5" size="19">mdi-map-marker-check</v-icon>
          <input v-model.trim="destinationQuery" type="text" placeholder="შეიყვანე დანიშნულების ადგილი" @keyup.enter="searchDestination" />
          <button class="search-mini" :disabled="searching || !destinationQuery" @click="searchDestination"><v-icon small>mdi-magnify</v-icon></button>
        </div>
      </div>
      <div v-if="destinationText" class="selected-destination"><v-icon color="#742BFF" small>mdi-check-circle</v-icon>{{ destinationText }}</div>
      <v-btn block outlined color="#742BFF" class="route-button" :loading="routing" :disabled="routing || !pickupCoordinates || !destinationCoordinates" @click="calculateTripRoute">
        <v-icon left>mdi-route</v-icon> მარშრუტის გამოთვლა
      </v-btn>
      <div v-if="routeSummary" class="route-summary">
        <div><strong>{{ routeDistance }}</strong><span>მანძილი</span></div>
        <div><strong>{{ routeDuration }}</strong><span>სავარაუდო დრო</span></div>
      </div>
      <v-alert v-if="locationMessage" dense text :type="locationError ? 'warning' : 'success'" class="location-alert">{{ locationMessage }}</v-alert>
      <v-alert v-if="routeSummary" dense text type="info" class="location-alert">მარშრუტი გამოთვლილია. მგზავრობის ფასის შეთავაზება და შეკვეთის გაგზავნა ჩაირთვება ტარიფებისა და შეკვეთის სისტემის შემოწმების შემდეგ.</v-alert>
    </v-card>

    <v-card class="notice-card" elevation="0">
      <div class="notice-icon"><v-icon color="#742BFF" size="25">mdi-shield-check-outline</v-icon></div>
      <div class="notice-content">
        <h2>უსაფრთხო მგზავრობა</h2>
        <p>მგზავრობის დაწყების შემდეგ აპში გამოჩნდება მძღოლის მონაცემები, მანქანის ნომერი და LIVE TRACK — მხოლოდ აქტიური შეკვეთის დროს.</p>
      </div>
    </v-card>

    <div class="quick-title">ჩემი განყოფილებები</div>
    <div class="quick-grid">
      <button class="quick-tile" @click="$router.push({ name: 'orders' })"><v-icon>mdi-receipt-text-outline</v-icon><span>შეკვეთები</span><small>შეთავაზებები და ისტორია</small></button>
      <button class="quick-tile" @click="$router.push({ name: 'profile' })"><v-icon>mdi-account-cog-outline</v-icon><span>პროფილი</span><small>პირადი მონაცემები</small></button>
    </div>
  </div>
</template>

<script>
import { Geolocation } from '@capacitor/geolocation'
import supabase from '@/services/supabase'
import TomTomMap from '@/components/passenger/TomTomMap.vue'

export default {
  name: 'PassengerHome',
  components: { TomTomMap },
  data() {
    return {
      firstName: '',
      pickupText: '',
      destinationQuery: '',
      destinationText: '',
      pickupCoordinates: null,
      destinationCoordinates: null,
      locating: false,
      searching: false,
      routing: false,
      locationMessage: '',
      locationError: false,
      routeSummary: null
    }
  },
  computed: {
    routeDistance() {
      return this.routeSummary ? (this.routeSummary.lengthInMeters / 1000).toFixed(1) + ' კმ' : ''
    },
    routeDuration() {
      return this.routeSummary ? Math.max(1, Math.round(this.routeSummary.travelTimeInSeconds / 60)) + ' წთ' : ''
    }
  },
  async mounted() {
    // Ask for location as soon as the passenger home screen opens.
    this.useMyLocation()
    if (!supabase) return
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data } = await supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
      if (data && data.full_name) this.firstName = data.full_name.trim().split(/\s+/)[0]
    } catch (error) {
      // The map and booking form remain usable if profile details cannot load.
    }
  },
  methods: {
    callEmergency() {
      window.location.href = 'tel:112'
    },
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
        const lng = position.coords.longitude
        const lat = position.coords.latitude
        this.pickupCoordinates = [lng, lat]
        this.$refs.tomtomMap.setUserLocation(lng, lat)
        try {
          this.pickupText = await this.$refs.tomtomMap.reverseLookup(lng, lat)
          this.locationMessage = 'შენი მიმდინარე მისამართი GPS-ით განისაზღვრა.'
        } catch (lookupError) {
          this.pickupText = lat.toFixed(6) + ', ' + lng.toFixed(6)
          this.locationMessage = 'GPS კოორდინატები მიღებულია; მისამართის ამოცნობა ვერ მოხერხდა.'
        }
      } catch (error) {
        this.locationError = true
        this.locationMessage = error && error.message ? error.message : 'მდებარეობის მიღება ვერ მოხერხდა. შეამოწმე Location პარამეტრები.'
      } finally {
        this.locating = false
      }
    },
    async searchDestination() {
      if (!this.destinationQuery.trim()) return
      this.searching = true
      this.locationMessage = ''
      this.locationError = false
      try {
        const result = await this.$refs.tomtomMap.searchAddress(this.destinationQuery, this.pickupCoordinates)
        this.destinationCoordinates = result.coordinates
        this.destinationText = result.address
        this.destinationQuery = result.address
        this.routeSummary = null
        this.locationMessage = 'დანიშნულების მისამართი მოიძებნა.'
      } catch (error) {
        this.locationError = true
        this.locationMessage = error && error.message ? error.message : 'მისამართის ძებნა ვერ მოხერხდა.'
      } finally {
        this.searching = false
      }
    },
    async calculateTripRoute() {
      if (!this.pickupCoordinates || !this.destinationCoordinates) return
      this.routing = true
      this.locationMessage = ''
      this.locationError = false
      try {
        this.routeSummary = await this.$refs.tomtomMap.routeBetween([
          this.pickupCoordinates,
          this.destinationCoordinates
        ])
      } catch (error) {
        this.locationError = true
        this.locationMessage = error && error.message ? error.message : 'მარშრუტის გამოთვლა ვერ მოხერხდა.'
      } finally {
        this.routing = false
      }
    }
  }
}
</script>

<style scoped>
.home-page { color:#e3e9f5; }
.welcome-row { display:flex; align-items:center; justify-content:space-between; margin:5px 0 18px; }
.welcome-row h1 { margin:7px 0 3px; font-size:23px; color:#f4f6fb; font-weight:800; }
.welcome-row p { margin:0; font-size:12px; color:#8796b1; }
.sos-mini { display:flex; align-items:center; gap:6px; padding:9px 11px; border-radius:12px; background:#7f1d2d; color:#fff; font-size:11px; font-weight:900; }
.booking-card, .notice-card { padding:17px; border-radius:17px !important; border:1px solid rgba(82,145,225,.18) !important; background:#102544 !important; color:#e3e9f5; }
.booking-heading { display:flex; align-items:center; gap:10px; font-size:15px; font-weight:800; margin-bottom:15px; }
.location-field { padding:8px 0 12px; }
.location-field label { display:block; color:#8292af; font-size:10px; margin:0 0 6px; }
.input-line { display:flex; align-items:center; gap:8px; min-height:45px; border:1px solid rgba(82,145,225,.2); border-radius:11px; background:#0C1D35; padding:0 10px; }
.input-line input { min-width:0; flex:1; border:0; outline:0; color:#e3e9f5; background:transparent; font:inherit; font-size:12px; padding:12px 0; }
.input-line input::placeholder { color:#657691; }
.gps-mini, .search-mini { color:#742BFF; padding:7px; }
.selected-destination { color:#c3d0e3; font-size:10px; margin:0 0 12px; display:flex; align-items:center; gap:6px; }
.route-button { margin:4px 0 0; border-radius:10px; font-size:11px !important; }
.route-summary { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:14px; padding:13px; border-radius:12px; background:#0C1D35; }
.route-summary div { display:flex; flex-direction:column; gap:4px; }
.route-summary strong { color:#742BFF; font-size:18px; }
.route-summary span { color:#8796b1; font-size:10px; }
.location-alert { margin-top:12px; font-size:10px; }
.notice-card { display:flex; gap:13px; margin-top:16px; background:linear-gradient(135deg,#1A3B66,#102544) !important; }
.notice-icon { flex:0 0 43px; width:43px; height:43px; display:flex; align-items:center; justify-content:center; border-radius:13px; background:rgba(116,43,255,.1); }
.notice-content h2 { margin:0 0 7px; font-size:13px; color:#f3f6fc; }
.notice-content p { margin:0; color:#9ba9bf; font-size:10px; line-height:1.6; }
.quick-title { margin:21px 0 11px; color:#dfe6f3; font-size:13px; font-weight:800; }
.quick-grid { display:grid; grid-template-columns:1fr 1fr; gap:11px; }
.quick-tile { display:flex; flex-direction:column; align-items:flex-start; gap:7px; padding:15px; border-radius:14px; border:1px solid rgba(82,145,225,.18); background:#102544; color:#e3e9f5; text-align:left; }
.quick-tile .v-icon { color:#742BFF; }
.quick-tile span { font-size:12px; font-weight:800; }
.quick-tile small { color:#8292af; font-size:10px; }
</style>
