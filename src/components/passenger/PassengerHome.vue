<template>
  <div class="home-page">
    <header class="route-header">
      <button class="back-button" aria-label="უკან" @click="$router.push({ name: 'profile' })">
        <v-icon>mdi-arrow-left</v-icon>
      </button>
      <div><h1>მარშრუტი</h1><p>აირჩიე საიდან და სად მიდიხარ</p></div>
      <button class="sos-mini" @click="callEmergency"><v-icon color="#fff" size="18">mdi-phone-alert</v-icon><span>SOS</span></button>
    </header>

    <section class="route-editor">
      <div class="route-track">
        <div class="route-point pickup-point"><span class="point-dot"></span></div>
        <div class="route-connector"></div>
        <div v-for="(stop, index) in stops" :key="'stop-dot-' + index" class="route-point stop-point"><span class="point-stop"></span></div>
        <div class="route-point dropoff-point"><span class="point-square"></span></div>
      </div>
      <div class="route-fields">
        <div class="location-field">
          <label>საიდან</label>
          <div class="input-line">
            <input v-model.trim="pickupText" type="text" placeholder="მიმდინარე მდებარეობა" @input="invalidatePickup">
            <button class="field-action" :disabled="locating" aria-label="ჩემი მდებარეობა" @click="useMyLocation"><v-icon small>mdi-crosshairs-gps</v-icon></button>
            <button class="field-action" :disabled="searchingPickup || !pickupText" aria-label="მისამართის ძებნა" @click="searchPickup"><v-icon small>mdi-magnify</v-icon></button>
          </div>
        </div>
        <div v-for="(stop, index) in stops" :key="'stop-field-' + index" class="location-field stop-field">
          <label>გაჩერება {{ index + 1 }}</label>
          <div class="input-line">
            <input v-model.trim="stop.query" type="text" placeholder="შეიყვანე გაჩერების მისამართი" @input="invalidateStop(index)" @keyup.enter="searchStop(index)">
            <button class="field-action" :disabled="searchingStop === index || !stop.query" @click="searchStop(index)"><v-icon small>mdi-magnify</v-icon></button>
            <button class="field-action remove-stop" aria-label="გაჩერების წაშლა" @click="removeStop(index)"><v-icon small>mdi-close</v-icon></button>
          </div>
        </div>
        <div class="location-field">
          <label>სად</label>
          <div class="input-line">
            <input v-model.trim="destinationQuery" type="text" placeholder="საბოლოო მისამართი" @input="invalidateDestination" @keyup.enter="searchDestination">
            <button class="field-action" :disabled="searchingDestination || !destinationQuery" aria-label="დანიშნულების ძებნა" @click="searchDestination"><v-icon small>mdi-magnify</v-icon></button>
          </div>
        </div>
      </div>
      <div class="route-tools">
        <button class="tool-button" :disabled="stops.length >= 4" @click="addStop"><v-icon small>mdi-plus</v-icon> გაჩერების დამატება</button>
        <button class="tool-button" @click="swapRoute"><v-icon small>mdi-swap-vertical</v-icon> მიმართულების შეცვლა</button>
      </div>
    </section>

    <section v-if="recentDestinations.length" class="recent-section">
      <div class="section-title">ბოლო მისამართები</div>
      <button v-for="(place, index) in recentDestinations" :key="index" class="recent-place" @click="selectRecent(place)">
        <v-icon class="recent-icon" small>mdi-history</v-icon>
        <span class="recent-copy"><strong>{{ place.address }}</strong><small>ბოლო ძიება</small></span>
        <v-icon small class="recent-arrow">mdi-arrow-up-left</v-icon>
      </button>
    </section>

    <TomTomMap ref="tomtomMap" />

    <v-alert v-if="locationMessage" dense text :type="locationError ? 'warning' : 'success'" class="location-alert">{{ locationMessage }}</v-alert>
    <v-btn block color="#2F80FF" dark class="route-button" :loading="routing" :disabled="routing || !canCalculateRoute" @click="calculateTripRoute">
      <v-icon left>mdi-route</v-icon> მარშრუტისა და ფასის გამოთვლა
    </v-btn>

    <section v-if="routeSummary" class="route-summary">
      <div><strong>{{ routeDistance }}</strong><span>მანძილი</span></div>
      <div><strong>{{ routeDuration }}</strong><span>სავარაუდო დრო</span></div>
    </section>

    <section v-if="quoteOptions.length" class="fare-section">
      <div class="section-title">აირჩიე ავტომობილის კატეგორია</div>
      <p class="fare-note">ფასი დათვლილია MOONRIDE GO ტარიფით და შენახულია შეთავაზების სახით.</p>
      <article v-for="option in quoteOptions" :key="option.category_code" class="fare-card">
        <div class="fare-main">
          <div class="fare-icon"><v-icon color="#70B7FF">{{ categoryIcon(option.category_code) }}</v-icon></div>
          <div class="fare-copy"><strong>{{ categoryLabel(option.category_code) }}</strong><small>{{ Number(option.rate_per_km).toFixed(2) }} {{ option.currency_code }}/კმ</small></div>
          <div class="fare-price">{{ formatFare(option.total_fare, option.currency_code) }}</div>
        </div>
        <v-btn block outlined color="#2F80FF" class="choose-fare" :loading="bookingCategory === option.category_code" :disabled="!!bookingCategory" @click="bookRide(option)">
          ამ კატეგორიის შეკვეთა
        </v-btn>
      </article>
      <p v-if="quoteExpiresAt" class="quote-expiry">შეთავაზების ვადა: {{ formatExpiry(quoteExpiresAt) }}</p>
    </section>

    <v-alert v-if="activeRide" dense text :type="activeRide.offers_sent > 0 ? 'success' : 'info'" class="ride-created">
      <strong>შეკვეთა მიღებულია</strong>
      <div>სტატუსი: {{ activeRide.offers_sent > 0 ? 'მძღოლების ძიება მიმდინარეობს' : 'მძღოლების ძიება გრძელდება' }}</div>
      <div>შეკვეთის ნომერი: {{ String(activeRide.ride_id).slice(0, 8).toUpperCase() }}</div>
      <div>გადახდა: ნაღდი ანგარიშსწორება</div>
      <v-btn text color="#8BCBFF" small @click="$router.push({ name: 'orders' })">შეკვეთების ნახვა</v-btn>
    </v-alert>

    <v-alert v-if="quoteOptions.length === 0 && quoteError" dense text type="warning" class="location-alert">{{ quoteError }}</v-alert>
    <v-card class="notice-card" elevation="0">
      <v-icon color="#2F80FF" size="25">mdi-shield-check-outline</v-icon>
      <div><strong>უსაფრთხო მგზავრობა</strong><p>მძღოლის მონაცემები, ავტომობილის ნომერი და LIVE TRACK გამოჩნდება მხოლოდ აქტიური შეკვეთისას.</p></div>
    </v-card>
  </div>
</template>

<script>
import { Geolocation } from '@capacitor/geolocation'
import supabase from '@/services/supabase'
import TomTomMap from '@/components/passenger/TomTomMap.vue'

const VISIBLE_GO_CATEGORIES = ['ECONOM_GO', 'ECONOM_PLUS_GO', 'COMFORT_GO', 'COMFORT_PLUS_GO', 'XL_GO', 'PREMIUM_GO']

export default {
  name: 'PassengerHome',
  components: { TomTomMap },
  data() {
    return {
      firstName: '',
      passengerUserId: '',
      pickupText: '',
      destinationQuery: '',
      destinationText: '',
      pickupCoordinates: null,
      destinationCoordinates: null,
      stops: [],
      locating: false,
      searchingPickup: false,
      searchingDestination: false,
      searchingStop: null,
      routing: false,
      locationMessage: '',
      locationError: false,
      routeSummary: null,
      cityId: '',
      cityName: '',
      quoteId: '',
      quoteOptions: [],
      quoteExpiresAt: '',
      quoteError: '',
      bookingCategory: '',
      activeRide: null,
      recentDestinations: []
    }
  },
  computed: {
    routeDistance() {
      return this.routeSummary ? (Number(this.routeSummary.lengthInMeters) / 1000).toFixed(1) + ' კმ' : ''
    },
    routeDuration() {
      return this.routeSummary ? Math.max(1, Math.round(Number(this.routeSummary.travelTimeInSeconds) / 60)) + ' წთ' : ''
    },
    canCalculateRoute() {
      return !!this.pickupCoordinates && !!this.destinationCoordinates &&
        this.stops.every(stop => Array.isArray(stop.coordinates) && stop.coordinates.length === 2)
    }
  },
  async mounted() {
    if (supabase) {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        if (user) {
          this.passengerUserId = user.id
          this.loadRecentDestinations()
          const { data } = await supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
          if (data && data.full_name) this.firstName = data.full_name.trim().split(/\s+/)[0]
        }
      } catch (error) {
        // Route selection stays available if the optional profile lookup fails.
      }
    }
    this.useMyLocation()
  },
  methods: {
    callEmergency() {
      window.location.href = 'tel:112'
    },
    clearQuote() {
      this.routeSummary = null
      this.quoteId = ''
      this.quoteOptions = []
      this.quoteExpiresAt = ''
      this.quoteError = ''
      this.activeRide = null
    },
    invalidatePickup() {
      this.pickupCoordinates = null
      this.clearQuote()
    },
    invalidateDestination() {
      this.destinationCoordinates = null
      this.destinationText = ''
      this.clearQuote()
    },
    invalidateStop(index) {
      if (this.stops[index]) this.stops[index].coordinates = null
      this.clearQuote()
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
        const position = await Geolocation.getCurrentPosition({ enableHighAccuracy: true, timeout: 20000, maximumAge: 15000 })
        const lng = position.coords.longitude
        const lat = position.coords.latitude
        this.pickupCoordinates = [lng, lat]
        this.$refs.tomtomMap.setUserLocation(lng, lat)
        try {
          this.pickupText = await this.$refs.tomtomMap.reverseLookup(lng, lat)
          this.locationMessage = 'საწყისი მისამართი GPS-ით განისაზღვრა.'
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
    async searchPickup() {
      if (!this.pickupText.trim()) return
      this.searchingPickup = true
      this.locationMessage = ''
      try {
        const result = await this.$refs.tomtomMap.searchAddress(this.pickupText, this.pickupCoordinates)
        this.pickupCoordinates = result.coordinates
        this.pickupText = result.address
        this.$refs.tomtomMap.setUserLocation(result.coordinates[0], result.coordinates[1])
        this.clearQuote()
      } catch (error) {
        this.locationError = true
        this.locationMessage = error.message || 'საწყისი მისამართის ძებნა ვერ მოხერხდა.'
      } finally {
        this.searchingPickup = false
      }
    },
    async searchDestination() {
      if (!this.destinationQuery.trim()) return
      this.searchingDestination = true
      this.locationMessage = ''
      this.locationError = false
      try {
        const result = await this.$refs.tomtomMap.searchAddress(this.destinationQuery, this.pickupCoordinates)
        this.destinationCoordinates = result.coordinates
        this.destinationText = result.address
        this.destinationQuery = result.address
        this.rememberDestination(result.address, result.coordinates)
        this.clearQuote()
        this.locationMessage = 'დანიშნულების მისამართი მოიძებნა.'
      } catch (error) {
        this.locationError = true
        this.locationMessage = error && error.message ? error.message : 'მისამართის ძებნა ვერ მოხერხდა.'
      } finally {
        this.searchingDestination = false
      }
    },
    addStop() {
      if (this.stops.length >= 4) return
      this.stops.push({ query: '', coordinates: null, address: '' })
      this.clearQuote()
    },
    removeStop(index) {
      this.stops.splice(index, 1)
      this.clearQuote()
    },
    async searchStop(index) {
      const stop = this.stops[index]
      if (!stop || !stop.query.trim()) return
      this.searchingStop = index
      this.locationMessage = ''
      try {
        const result = await this.$refs.tomtomMap.searchAddress(stop.query, this.pickupCoordinates)
        this.$set(stop, 'coordinates', result.coordinates)
        this.$set(stop, 'address', result.address)
        this.$set(stop, 'query', result.address)
        this.clearQuote()
        this.locationMessage = 'გაჩერების მისამართი მოიძებნა.'
      } catch (error) {
        this.locationError = true
        this.locationMessage = error.message || 'გაჩერების მისამართის ძებნა ვერ მოხერხდა.'
      } finally {
        this.searchingStop = null
      }
    },
    swapRoute() {
      const oldPickupText = this.pickupText
      const oldPickupCoordinates = this.pickupCoordinates
      this.pickupText = this.destinationText || this.destinationQuery
      this.pickupCoordinates = this.destinationCoordinates
      this.destinationQuery = oldPickupText
      this.destinationText = oldPickupText
      this.destinationCoordinates = oldPickupCoordinates
      this.stops.reverse()
      this.clearQuote()
    },
    recentStorageKey() {
      return this.passengerUserId ? 'moonride.recentDestinations.' + this.passengerUserId : null
    },
    loadRecentDestinations() {
      const storageKey = this.recentStorageKey()
      if (!storageKey) return
      try {
        const saved = JSON.parse(window.localStorage.getItem(storageKey) || '[]')
        this.recentDestinations = Array.isArray(saved) ? saved.filter(p =>
          p && typeof p.address === 'string' && Array.isArray(p.coordinates) &&
          p.coordinates.length === 2 && p.coordinates.every(Number.isFinite)
        ).slice(0, 5) : []
      } catch (error) {
        this.recentDestinations = []
      }
    },
    rememberDestination(address, coordinates) {
      const next = [{ address, coordinates }, ...this.recentDestinations.filter(p => p.address !== address)].slice(0, 5)
      this.recentDestinations = next
      const storageKey = this.recentStorageKey()
      if (storageKey) {
        try { window.localStorage.setItem(storageKey, JSON.stringify(next)) } catch (error) {}
      }
    },
    selectRecent(place) {
      this.destinationQuery = place.address
      this.destinationText = place.address
      this.destinationCoordinates = place.coordinates.slice()
      this.clearQuote()
      this.destinationText = place.address
      this.destinationCoordinates = place.coordinates.slice()
    },
    async getServiceCity() {
      if (this.cityId) return { id: this.cityId, name: this.cityName }
      if (!supabase) throw new Error('Supabase კავშირი არ არის გამართული.')
      const { data, error } = await supabase.from('cities')
        .select('id,name,latitude,longitude,is_active,service_enabled')
        .eq('is_active', true)
        .eq('service_enabled', true)
      if (error) throw error
      if (!data || data.length === 0) throw new Error('ამჟამად აქტიური მომსახურების ქალაქი არ არის.')
      const point = this.pickupCoordinates
      const distanceKm = city => {
        if (!point || city.latitude == null || city.longitude == null) return Number.POSITIVE_INFINITY
        const toRad = value => value * Math.PI / 180
        const dLat = toRad(Number(city.latitude) - point[1])
        const dLng = toRad(Number(city.longitude) - point[0])
        const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(point[1])) * Math.cos(toRad(Number(city.latitude))) * Math.sin(dLng / 2) ** 2
        return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      }
      const city = data.slice().sort((a, b) => distanceKm(a) - distanceKm(b))[0]
      this.cityId = city.id
      this.cityName = city.name
      return city
    },
    async calculateTripRoute() {
      if (!this.canCalculateRoute || !supabase) return
      this.routing = true
      this.locationMessage = ''
      this.locationError = false
      this.quoteError = ''
      this.activeRide = null
      this.quoteOptions = []
      try {
        const allLocations = [this.pickupCoordinates, ...this.stops.map(stop => stop.coordinates), this.destinationCoordinates]
        this.routeSummary = await this.$refs.tomtomMap.routeBetween(allLocations)
        const city = await this.getServiceCity()
        const points = [
          { point_type: 'pickup', latitude: this.pickupCoordinates[1], longitude: this.pickupCoordinates[0], address: this.pickupText },
          ...this.stops.map(stop => ({ point_type: 'stop', latitude: stop.coordinates[1], longitude: stop.coordinates[0], address: stop.address || stop.query })),
          { point_type: 'dropoff', latitude: this.destinationCoordinates[1], longitude: this.destinationCoordinates[0], address: this.destinationText || this.destinationQuery }
        ]
        const { data, error } = await supabase.functions.invoke('quote-route', { body: { cityId: city.id, points } })
        if (error) throw error
        if (!data || !data.quoteId || !Array.isArray(data.options)) throw new Error('ფასის სერვისმა არასრული პასუხი დააბრუნა.')
        this.quoteId = data.quoteId
        this.quoteExpiresAt = data.expiresAt || ''
        this.routeSummary = {
          lengthInMeters: Number(data.distanceKm) * 1000,
          travelTimeInSeconds: Number(data.durationMinutes) * 60
        }
        this.quoteOptions = data.options.filter(option => VISIBLE_GO_CATEGORIES.includes(option.category_code))
        if (!this.quoteOptions.length) throw new Error('ამ მარშრუტისთვის ხელმისაწვდომი GO კატეგორია ვერ მოიძებნა.')
        if (data.options.some(option => ['GROUP_RIDE_GO', 'MINIVAN_GO'].includes(option.category_code))) {
          this.quoteError = 'ჯგუფური მგზავრობა და მინივენი დამალულია MOONRIDE GO-ის შეთანხმებული კატეგორიების შესაბამისად.'
        }
        this.locationMessage = 'მარშრუტი და ფასები წარმატებით გამოითვალა.'
      } catch (error) {
        this.quoteId = ''
        this.quoteOptions = []
        this.quoteError = error && error.message ? error.message : 'მარშრუტის ან ფასის გამოთვლა ვერ მოხერხდა.'
        this.locationError = true
        this.locationMessage = this.quoteError
      } finally {
        this.routing = false
      }
    },
    async bookRide(option) {
      if (!this.quoteId || !supabase || this.bookingCategory) return
      this.bookingCategory = option.category_code
      this.quoteError = ''
      try {
        const { data: selected, error: selectError } = await supabase.functions.invoke('quote-route', {
          body: { action: 'select_category', quoteId: this.quoteId, categoryCode: option.category_code }
        })
        if (selectError) throw selectError
        if (!selected || selected.categoryCode !== option.category_code) throw new Error('არჩეული კატეგორიის დადასტურება ვერ მოხერხდა.')
        const { data, error } = await supabase.rpc('go_create_ride_from_quote', {
          p_quote_id: this.quoteId,
          p_category_code: option.category_code,
          p_payment_method: 'cash'
        })
        if (error) throw error
        if (!data || !data.ride_id) throw new Error('შეკვეთა შეიქმნა არასრული პასუხით.')
        this.activeRide = data
        this.locationMessage = data.offers_sent > 0
          ? 'შეკვეთა გაიგზავნა ახლომდებარე დამტკიცებულ მძღოლებთან.'
          : 'შეკვეთა მიღებულია. ახლომდებარე მძღოლების ძიება მიმდინარეობს.'
        this.rememberDestination(this.destinationText || this.destinationQuery, this.destinationCoordinates)
      } catch (error) {
        this.quoteError = error && error.message ? error.message : 'შეკვეთის შექმნა ვერ მოხერხდა.'
        this.locationError = true
        this.locationMessage = this.quoteError
      } finally {
        this.bookingCategory = ''
      }
    },
    categoryLabel(code) {
      const labels = {
        ECONOM_GO: 'ECONOM GO',
        ECONOM_PLUS_GO: 'ECONOM+ GO',
        COMFORT_GO: 'COMFORT GO',
        COMFORT_PLUS_GO: 'COMFORT+ GO',
        XL_GO: 'XL GO',
        PREMIUM_GO: 'PREMIUM GO'
      }
      return labels[code] || code
    },
    categoryIcon(code) {
      const icons = {
        ECONOM_GO: 'mdi-car-hatchback',
        ECONOM_PLUS_GO: 'mdi-car-hatchback',
        COMFORT_GO: 'mdi-car',
        COMFORT_PLUS_GO: 'mdi-car',
        XL_GO: 'mdi-car-estate',
        PREMIUM_GO: 'mdi-car-sports'
      }
      return icons[code] || 'mdi-car'
    },
    formatFare(value, currency) {
      return Number(value).toFixed(2) + ' ' + (currency || 'GEL')
    },
    formatExpiry(value) {
      const date = new Date(value)
      return Number.isNaN(date.getTime()) ? 'ვადა არ არის მითითებული' : date.toLocaleTimeString('ka-GE', { hour: '2-digit', minute: '2-digit' })
    }
  }
}
</script>

<style scoped>
.home-page { color:#e3e9f5; padding-bottom:20px; }
.route-header { display:flex; align-items:center; gap:12px; margin:3px 0 17px; }
.route-header h1 { margin:0; color:#f4f7fc; font-size:22px; font-weight:850; }
.route-header p { margin:4px 0 0; color:#8296b5; font-size:11px; }
.back-button { width:36px; height:36px; border-radius:11px; color:#dceaff; background:#102544; }
.sos-mini { margin-left:auto; display:flex; align-items:center; gap:5px; padding:8px 10px; border-radius:11px; background:#7f1d2d; color:#fff; font-size:10px; font-weight:900; }
.route-editor { display:grid; grid-template-columns:28px minmax(0,1fr); gap:0 9px; padding:12px 11px 10px; border:2px solid rgba(47,128,255,.68); border-radius:16px; background:#102544; }
.route-track { display:flex; flex-direction:column; align-items:center; padding-top:16px; }
.route-point { display:flex; justify-content:center; align-items:center; width:18px; height:24px; flex:0 0 24px; }
.point-dot { width:13px; height:13px; border:4px solid #55b4ff; border-radius:50%; background:#102544; }
.route-connector { min-height:26px; width:2px; flex:1; background:rgba(141,190,240,.38); }
.point-stop { width:9px; height:9px; border-radius:50%; background:#70b7ff; }
.point-square { width:12px; height:12px; border:3px solid #e7f1ff; border-radius:2px; background:#102544; }
.route-fields { min-width:0; }
.location-field { padding:3px 0 8px; }
.location-field + .location-field { border-top:1px solid rgba(149,178,218,.15); padding-top:9px; }
.location-field label { display:block; color:#8fa7c9; font-size:10px; margin:0 0 4px; }
.input-line { display:flex; align-items:center; min-height:31px; gap:4px; }
.input-line input { min-width:0; flex:1; border:0; outline:0; color:#f2f6ff; background:transparent; font:inherit; font-size:13px; padding:6px 1px; }
.input-line input::placeholder { color:#7c8faa; }
.field-action { display:flex; align-items:center; justify-content:center; flex:0 0 30px; width:30px; height:30px; color:#8bcaff; border-radius:8px; background:#17365c; }
.field-action:disabled { opacity:.35; }
.remove-stop { color:#e1a2ae; }
.route-tools { grid-column:1 / -1; display:flex; justify-content:space-between; gap:8px; padding:10px 1px 0; }
.tool-button { display:flex; align-items:center; gap:5px; color:#8bcaff; font-size:10px; font-weight:700; }
.tool-button:disabled { opacity:.35; }
.recent-section { margin:17px 0; }
.section-title { color:#eef4ff; font-size:13px; font-weight:800; margin-bottom:8px; }
.recent-place { display:flex; align-items:center; width:100%; gap:12px; min-height:55px; padding:8px 2px; border-bottom:1px solid rgba(149,178,218,.12); text-align:left; }
.recent-icon { color:#9caec6; }
.recent-copy { display:flex; flex:1; min-width:0; flex-direction:column; gap:4px; }
.recent-copy strong { overflow:hidden; white-space:nowrap; text-overflow:ellipsis; color:#edf4ff; font-size:12px; font-weight:650; }
.recent-copy small { color:#8296b5; font-size:10px; }
.recent-arrow { color:#7f91ac; }
.tomtom-map-card { margin:17px 0 13px; }
.location-alert { margin:10px 0; font-size:10px; }
.route-button { margin:4px 0 12px; border-radius:11px; font-size:11px !important; font-weight:800; }
.route-summary { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin:0 0 15px; padding:13px; border-radius:12px; background:#102544; border:1px solid rgba(82,145,225,.18); }
.route-summary div { display:flex; flex-direction:column; gap:4px; }
.route-summary strong { color:#48b7ff; font-size:18px; }
.route-summary span { color:#8796b1; font-size:10px; }
.fare-section { margin:16px 0; }
.fare-note { margin:0 0 10px; color:#8498b7; font-size:10px; line-height:1.5; }
.fare-card { margin:9px 0; padding:12px; background:#102544; border:1px solid rgba(82,145,225,.2); border-radius:14px; }
.fare-main { display:flex; align-items:center; gap:10px; margin-bottom:10px; }
.fare-icon { width:38px; height:38px; display:flex; align-items:center; justify-content:center; border-radius:11px; background:#183a64; }
.fare-copy { display:flex; flex:1; flex-direction:column; gap:4px; min-width:0; }
.fare-copy strong { color:#f0f5ff; font-size:12px; }
.fare-copy small { color:#8ca2c3; font-size:10px; }
.fare-price { color:#8bcaff; font-size:15px; font-weight:900; white-space:nowrap; }
.choose-fare { border-radius:9px; font-size:10px !important; }
.quote-expiry { margin:8px 0; color:#8296b5; font-size:10px; }
.ride-created { margin:12px 0; font-size:11px; }
.ride-created strong { display:block; margin-bottom:5px; }
.notice-card { display:flex; align-items:flex-start; gap:12px; margin-top:18px; padding:14px; border:1px solid rgba(82,145,225,.18); border-radius:15px; background:#102544; }
.notice-card strong { color:#eef4ff; font-size:12px; }
.notice-card p { color:#91a3c1; font-size:10px; line-height:1.5; margin:5px 0 0; }
@media (min-width:700px) {
  .home-page { max-width:760px; margin:0 auto; }
}
</style>
