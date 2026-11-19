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
      <div v-for="(stop, index) in stops" :key="'stop-'+index" class="location-field">
        <label>გაჩერება {{ index + 1 }}</label>
        <div class="input-line">
          <v-icon color="#A56BFF" size="19">mdi-map-marker-plus</v-icon>
          <input v-model.trim="stop.query" type="text" placeholder="შუალედური მისამართი" @keyup.enter="searchStop(index)" />
          <button class="search-mini" :disabled="!stop.query || stop.searching" @click="searchStop(index)"><v-icon small>mdi-magnify</v-icon></button>
          <button class="remove-stop" @click="removeStop(index)" aria-label="გაჩერების წაშლა"><v-icon small>mdi-close</v-icon></button>
        </div>
        <div v-if="stop.address" class="selected-destination">{{ stop.address }}</div>
      </div>
      <button v-if="stops.length < 4" class="add-stop" @click="addStop"><v-icon small>mdi-plus</v-icon> გაჩერების დამატება</button>
      <v-btn block outlined color="#742BFF" class="route-button" :loading="routing" :disabled="routing || !pickupCoordinates || !destinationCoordinates" @click="calculateTripRoute">
        <v-icon left>mdi-route</v-icon> მარშრუტის გამოთვლა
      </v-btn>
      <div v-if="routeSummary" class="route-summary">
        <div><strong>{{ routeDistance }}</strong><span>მანძილი</span></div>
        <div><strong>{{ routeDuration }}</strong><span>სავარაუდო დრო</span></div>
      </div>
      <v-alert v-if="locationMessage" dense text :type="locationError ? 'warning' : 'success'" class="location-alert">{{ locationMessage }}</v-alert>
      <div class="category-heading">აირჩიე ავტომობილის კატეგორია</div>
      <div class="category-list">
        <button v-for="category in categories" :key="category.code" class="category-card" :class="{ active: selectedCategory === category.code }" @click="selectedCategory = category.code">
          <span class="category-icon"><v-icon>{{ category.icon }}</v-icon></span>
          <span class="category-info"><strong>{{ category.name }}</strong><small>{{ category.capacity }} მგზავრი</small></span>
          <span class="category-rate"><strong>{{ category.rate.toFixed(2) }} GEL</strong><small>1 კმ-ზე</small></span>
          <v-icon v-if="selectedCategory === category.code" color="#C49BFF">mdi-check-circle</v-icon>
        </button>
      </div>
      <div class="booking-options">
        <label>გადახდის მეთოდი</label>
        <select v-model="paymentMethod">
          <option value="cash">ნაღდი ფული მძღოლთან</option>
          <option value="tbc">TBC ბარათი</option>
          <option value="bog">საქართველოს ბანკი</option>
          <option value="wallet">MOONRIDE Wallet</option>
        </select>
        <label>მგზავრობის დრო</label>
        <select v-model="scheduleMode">
          <option value="now">ახლავე</option>
          <option value="scheduled">დაგეგმილი მგზავრობა</option>
        </select>
        <input v-if="scheduleMode === 'scheduled'" v-model="scheduledAt" type="datetime-local" />
      </div>
      <v-alert dense text type="info" class="location-alert">კატეგორიების ტარიფები ნაჩვენებია კილომეტრზე. საბოლოო ფასი და შეკვეთის დადასტურება ჩაირთვება მას შემდეგ, რაც Supabase-ის GO კალკულატორი და მძღოლების განაწილების სისტემა წარმატებით გაივლის ტესტირებას.</v-alert>
      <v-btn block color="#742BFF" class="request-button" disabled><v-icon left>mdi-taxi</v-icon> შეკვეთის გაგზავნა — მზადდება</v-btn>
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
      routeSummary: null,
      stops: [],
      selectedCategory: 'ECONOM_GO',
      paymentMethod: 'cash',
      scheduleMode: 'now',
      scheduledAt: '',
      categories: [
        { code: 'ECONOM_GO', name: 'ECONOM', rate: 1.20, capacity: 4, icon: 'mdi-car-hatchback' },
        { code: 'ECONOM_PLUS_GO', name: 'ECONOM+', rate: 1.25, capacity: 4, icon: 'mdi-car' },
        { code: 'COMFORT_GO', name: 'COMFORT', rate: 1.35, capacity: 4, icon: 'mdi-car-side' },
        { code: 'COMFORT_PLUS_GO', name: 'COMFORT+', rate: 1.60, capacity: 4, icon: 'mdi-car-sports' },
        { code: 'XL_GO', name: 'XL', rate: 1.71, capacity: 6, icon: 'mdi-car-estate' },
        { code: 'MINIVAN_GO', name: 'MINIVAN', rate: 1.85, capacity: 7, icon: 'mdi-van-passenger' },
        { code: 'GROUP_RIDE_GO', name: 'GROUP RIDE', rate: 1.17, capacity: 6, icon: 'mdi-account-group' }
      ]
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
    addStop() {
      if (this.stops.length < 4) this.stops.push({ query: '', address: '', coordinates: null, searching: false })
    },
    removeStop(index) {
      this.stops.splice(index, 1)
      this.routeSummary = null
    },
    async searchStop(index) {
      const stop = this.stops[index]
      if (!stop || !stop.query.trim()) return
      stop.searching = true
      try {
        const result = await this.$refs.tomtomMap.searchAddress(stop.query, this.pickupCoordinates)
        this.$set(stop, 'coordinates', result.coordinates)
        this.$set(stop, 'address', result.address)
        this.routeSummary = null
      } catch (error) {
        this.locationError = true
        this.locationMessage = error.message || 'გაჩერების ძებნა ვერ მოხერხდა.'
      } finally {
        stop.searching = false
      }
    },
    async calculateTripRoute() {
      if (!this.pickupCoordinates || !this.destinationCoordinates) return
      this.routing = true
      this.locationMessage = ''
      this.locationError = false
      try {
        const routePoints = [this.pickupCoordinates]
        for (const stop of this.stops) {
          if (!stop.coordinates) throw new Error('ჯერ მოძებნე ყველა შუალედური გაჩერების მისამართი.')
          routePoints.push(stop.coordinates)
        }
        routePoints.push(this.destinationCoordinates)
        this.routeSummary = await this.$refs.tomtomMap.routeBetween(routePoints)
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
.add-stop { display:flex; align-items:center; gap:6px; color:#C49BFF; font-size:11px; font-weight:700; padding:5px 0 12px; }
.remove-stop { color:#A8B5CB; padding:5px; }
.category-heading { margin:18px 0 10px; color:#f2f5fb; font-size:14px; font-weight:800; }
.category-list { display:flex; flex-direction:column; gap:8px; }
.category-card { display:flex; align-items:center; gap:10px; width:100%; padding:12px; border:1px solid rgba(116,43,255,.18); border-radius:13px; background:#0C1D35; color:#e3e9f5; text-align:left; }
.category-card.active { border:1.5px solid #A56BFF; background:linear-gradient(110deg,rgba(116,43,255,.22),#102544); box-shadow:0 0 15px rgba(116,43,255,.12); }
.category-icon { width:40px; height:40px; display:flex; align-items:center; justify-content:center; border-radius:11px; background:#25194E; color:#C49BFF; }
.category-info { display:flex; flex:1; flex-direction:column; gap:4px; }
.category-info strong { font-size:12px; }
.category-info small,.category-rate small { color:#8292af; font-size:9px; }
.category-rate { display:flex; flex-direction:column; align-items:flex-end; gap:4px; }
.category-rate strong { color:#C49BFF; font-size:12px; }
.booking-options { display:grid; gap:8px; margin-top:16px; }
.booking-options label { color:#9eacc2; font-size:10px; }
.booking-options select,.booking-options input { width:100%; padding:12px; border:1px solid rgba(116,43,255,.25); border-radius:10px; background:#0C1D35; color:#eef2fb; font-size:12px; }
.request-button { margin-top:13px; border-radius:12px; font-weight:800; }
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
