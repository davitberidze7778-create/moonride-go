<template>
  <div class="home-page">
    <div class="welcome-row">
      <div>
        <h1>გამარჯობა{{ firstName ? ', ' + firstName : '' }}!</h1>
        <p>სად წავიდეთ დღეს?</p>
      </div>
      <button v-if="featureEnabled('safety.sos')" class="sos-mini" @click="callEmergency"><v-icon color="#fff" size="20">mdi-phone-alert</v-icon><span>SOS</span></button>
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
      <button v-if="stops.length < 4 && featureEnabled('ride.multiple_stops')" class="add-stop" @click="addStop"><v-icon small>mdi-plus</v-icon> გაჩერების დამატება</button>
      <v-btn block outlined color="#742BFF" class="route-button" :loading="routing" :disabled="routing || !pickupCoordinates || !destinationCoordinates" @click="calculateTripRoute">
        <v-icon left>mdi-route</v-icon> მარშრუტის გამოთვლა
      </v-btn>
      <div v-if="routeSummary" class="route-summary">
        <div><strong>{{ routeDistance }}</strong><span>მანძილი</span></div>
        <div><strong>{{ routeDuration }}</strong><span>სავარაუდო დრო</span></div>
      </div>
      <v-alert v-if="locationMessage" dense text :type="locationError ? 'warning' : 'success'" class="location-alert">{{ locationMessage }}</v-alert>
      <div class="category-heading">აირჩიე ავტომობილის კატეგორია <small v-if="cityName">· {{ cityName }}</small></div>
      <v-progress-linear v-if="categoriesLoading" indeterminate color="#A56BFF" />
      <div v-if="!categoriesLoading && !categories.length" class="no-categories">ამ მდებარეობაზე აქტიური MOONRIDE GO ტარიფი ვერ მოიძებნა.</div>
      <div class="category-list" v-if="categories.length">
        <button v-for="category in categories" :key="category.code" class="category-card" :class="{ active: selectedCategory === category.code }" @click="selectCategory(category)">
          <span class="category-icon"><v-icon>{{ category.icon }}</v-icon></span>
          <span class="category-info"><strong>{{ category.name }}</strong><small>{{ category.capacity }} მგზავრი</small></span>
          <span class="category-rate"><strong>{{ category.estimatedFare !== null && category.estimatedFare !== undefined ? category.estimatedFare.toFixed(2) + ' ' + (currencyCode || 'GEL') : category.rate.toFixed(2) + ' ' + (currencyCode || 'GEL') }}</strong><small>{{ category.estimatedFare !== null && category.estimatedFare !== undefined ? 'სრული ფასი' : '1 კმ-ზე' }}</small></span>
          <v-icon v-if="selectedCategory === category.code" color="#C49BFF">mdi-check-circle</v-icon>
        </button>
      </div>
      <div class="booking-options">
        <label>გადახდის მეთოდი</label>
        <select v-model="paymentMethod">
          <option value="cash" :disabled="!featureEnabled('payment.cash')">ნაღდი ფული მძღოლთან</option>
          <option value="tbc" :disabled="!featureEnabled('payment.tbc')">TBC ბარათი</option>
          <option value="bog" :disabled="!featureEnabled('payment.bog')">საქართველოს ბანკი</option>
          <option value="wallet" :disabled="!featureEnabled('payment.wallet')">MOONRIDE Wallet</option>
        </select>
        <small class="payment-note">ადმინისტრატორი ააქტიურებს გადახდის მეთოდებს მას შემდეგ, რაც შესაბამისი უსაფრთხო გადახდის სისტემა მზად იქნება.</small>
        <label>მგზავრობის დრო</label>
        <select v-model="scheduleMode">
          <option value="now">ახლავე</option>
          <option value="scheduled" :disabled="!featureEnabled('ride.scheduled')">დაგეგმილი მგზავრობა</option>
        </select>
        <input v-if="scheduleMode === 'scheduled'" v-model="scheduledAt" type="datetime-local" />
      </div>
      <v-alert v-if="quoteId" dense text type="success" class="location-alert">Supabase GO შეთავაზება შეიქმნა · #{{ quoteId.slice(0, 8).toUpperCase() }} · ფასი შენახულია უცვლელი Snapshot-ით.</v-alert>
      <v-alert v-else dense text type="info" class="location-alert">მარშრუტის გამოთვლის შემდეგ Supabase-ის GO კალკულატორი დააბრუნებს საბოლოო ფასებს ყველა აქტიური კატეგორიისთვის.</v-alert>
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
      selectedCategory: '',
      paymentMethod: 'cash',
      scheduleMode: 'now',
      scheduledAt: '',
      cityId: '',
      cityName: '',
      tariffPlanId: '',
      currencyCode: '',
      categoriesLoading: false,
      categories: [],
      featureFlags: {},
      quoteId: '',
      selectedFare: null
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
    // Load the central feature switches before exposing passenger options.
    this.loadFeatureFlags()
    // Ask for location as soon as the passenger home screen opens.
    this.useMyLocation()
    if (!supabase) return
    this.setupSettingsWatcher()
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data } = await supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
      if (data && data.full_name) this.firstName = data.full_name.trim().split(/\s+/)[0]
    } catch (error) {
      // The map and booking form remain usable if profile details cannot load.
    }
  },
  beforeDestroy() {
    if (this._settingsInterval) window.clearInterval(this._settingsInterval)
    if (this._settingsChannel && supabase) supabase.removeChannel(this._settingsChannel)
  },
  methods: {
    setupSettingsWatcher() {
      if (!supabase) return
      this._settingsChannel = supabase
        .channel('moonride-go-passenger-live-settings')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'go_app_feature_flags' }, payload => {
          const row = payload.new || payload.old
          if (payload.eventType === 'DELETE') {
            if (row && row.feature_key) this.$delete(this.featureFlags, row.feature_key)
            return
          }
          if (row && row.feature_key) {
            this.$set(this.featureFlags, row.feature_key, Boolean(row.is_available && row.is_enabled))
          }
        })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'go_tariff_category_rates' }, () => this.refreshPassengerTariffs())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'go_tariff_plans' }, () => this.refreshPassengerTariffs())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'vehicle_categories' }, () => this.refreshPassengerTariffs())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'go_tariff_waiting_rules' }, () => this.refreshPassengerTariffs())
        .subscribe()
      this._settingsInterval = window.setInterval(() => {
        this.loadFeatureFlags()
        this.refreshPassengerTariffs()
      }, 30000)
    },
    refreshPassengerTariffs() {
      if (!this.pickupCoordinates || this.quoteId) return
      this.loadCityAndCategories(this.pickupCoordinates[0], this.pickupCoordinates[1])
    },
    featureEnabled(key) {
      return this.featureFlags[key] === true
    },
    async loadFeatureFlags() {
      if (!supabase) return
      try {
        const { data, error } = await supabase
          .from('go_app_feature_flags')
          .select('feature_key,is_enabled,is_available')
          .eq('is_available', true)
        if (error) throw error
        const flags = {}
        ;(data || []).forEach(flag => { flags[flag.feature_key] = Boolean(flag.is_enabled && flag.is_available) })
        this.featureFlags = flags
      } catch (error) {
        // Leave optional features hidden when their configuration cannot be verified.
        this.featureFlags = {}
      }
    },
    distanceKm(lat1, lon1, lat2, lon2) {
      const toRad = value => value * Math.PI / 180
      const dLat = toRad(lat2 - lat1)
      const dLon = toRad(lon2 - lon1)
      const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2
      return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    },
    async loadCityAndCategories(longitude, latitude) {
      if (!supabase) return
      this.categoriesLoading = true
      this.categories = []
      this.cityName = ''
      this.currencyCode = ''
      try {
        const { data: cityRows, error: cityError } = await supabase
          .from('cities')
          .select('id,name,latitude,longitude,is_active,service_enabled')
          .eq('is_active', true)
          .eq('service_enabled', true)
        if (cityError) throw cityError
        const nearest = (cityRows || [])
          .filter(city => Number.isFinite(Number(city.latitude)) && Number.isFinite(Number(city.longitude)))
          .map(city => ({ ...city, distance: this.distanceKm(latitude, longitude, Number(city.latitude), Number(city.longitude)) }))
          .sort((a, b) => a.distance - b.distance)[0]
        if (!nearest || nearest.distance > 60) {
          this.cityId = ''
          this.locationMessage = 'MOONRIDE GO ჯერ არ მუშაობს ამ ქალაქში.'
          return
        }
        this.cityId = nearest.id
        this.cityName = nearest.name
        const { data: plans, error: planError } = await supabase
          .from('go_tariff_plans')
          .select('id,plan_name,currency_code,effective_from,effective_until')
          .eq('city_id', nearest.id)
          .eq('scope_type', 'city')
          .eq('is_active', true)
          .order('effective_from', { ascending: false })
          .limit(10)
        if (planError) throw planError
        const now = Date.now()
        const plan = (plans || []).find(item =>
          new Date(item.effective_from).getTime() <= now &&
          (!item.effective_until || new Date(item.effective_until).getTime() > now)
        )
        if (!plan) {
          this.locationMessage = 'ამ ქალაქისთვის აქტიური GO ტარიფი ჯერ არ არის დაყენებული.'
          return
        }
        this.tariffPlanId = plan.id
        this.currencyCode = plan.currency_code || ''
        const { data: rates, error: rateError } = await supabase
          .from('go_tariff_category_rates')
          .select('id,category_id,rate_per_km')
          .eq('tariff_plan_id', plan.id)
        if (rateError) throw rateError
        const ids = (rates || []).map(row => row.category_id)
        if (!ids.length) return
        const { data: categoryRows, error: categoryError } = await supabase
          .from('vehicle_categories')
          .select('id,code,name,is_active')
          .in('id', ids)
          .eq('is_active', true)
        if (categoryError) throw categoryError
        const metadata = {
          ECONOM_GO: { name: 'ECONOM', capacity: 4, icon: 'mdi-car-hatchback' },
          ECONOM_PLUS_GO: { name: 'ECONOM+', capacity: 4, icon: 'mdi-car' },
          COMFORT_GO: { name: 'COMFORT', capacity: 4, icon: 'mdi-car-side' },
          COMFORT_PLUS_GO: { name: 'COMFORT+', capacity: 4, icon: 'mdi-car-sports' },
          XL_GO: { name: 'XL', capacity: 6, icon: 'mdi-car-estate' },
          MINIVAN_GO: { name: 'MINIVAN', capacity: 7, icon: 'mdi-van-passenger' },
          GROUP_RIDE_GO: { name: 'GROUP RIDE', capacity: 6, icon: 'mdi-account-group' }
        }
        const ratesById = {}
        ;(rates || []).forEach(row => { ratesById[row.category_id] = row })
        const order = ['ECONOM_GO','ECONOM_PLUS_GO','COMFORT_GO','COMFORT_PLUS_GO','XL_GO','MINIVAN_GO','GROUP_RIDE_GO']
        this.categories = (categoryRows || [])
          .filter(row => metadata[row.code] && ratesById[row.id])
          .sort((a, b) => order.indexOf(a.code) - order.indexOf(b.code))
          .map(row => ({
            id: row.id,
            code: row.code,
            name: metadata[row.code].name,
            capacity: metadata[row.code].capacity,
            icon: metadata[row.code].icon,
            rate: Number(ratesById[row.id].rate_per_km),
            currency: this.currencyCode
          }))
        if (!this.categories.some(item => item.code === this.selectedCategory)) {
          this.selectedCategory = this.categories.length ? this.categories[0].code : ''
        }
      } catch (error) {
        this.categories = []
        this.locationError = true
        this.locationMessage = error.message || 'GO ტარიფების ჩატვირთვა ვერ მოხერხდა.'
      } finally {
        this.categoriesLoading = false
      }
    },
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
        await this.loadCityAndCategories(lng, lat)
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
      this.quoteId = ''
      this.selectedFare = null
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
    async createFareQuote(points) {
      if (!supabase || !this.cityId || !this.featureEnabled('ride.quote')) return
      this.quoteId = ''
      this.selectedFare = null
      this.categories = this.categories.map(category => ({ ...category, estimatedFare: null }))
      const { data, error } = await supabase.functions.invoke('quote-route', {
        body: { cityId: this.cityId, points }
      })
      if (error) {
        const context = error.context
        let detail = error.message || 'Supabase-ის GO ფასის შეთავაზება ვერ შეიქმნა.'
        if (context && typeof context.json === 'function') {
          try {
            const payload = await context.json()
            if (payload && payload.error) detail = payload.error
          } catch (ignored) { /* Keep the original error message. */ }
        }
        if (String(detail).toLowerCase().includes('tomtom server key')) {
          detail = 'რუკა და მარშრუტის ჩვენება მუშაობს, მაგრამ საბოლოო ფასის სერვერულ გამოთვლას აკლია Supabase-ის Edge Function Secret: TOMTOM_API_KEY. დაამატე ეს გასაღები Supabase → Edge Functions → Secrets-ში; ჩატში ან აპის კოდში არ ჩაწერო.'
        }
        throw new Error(detail)
      }
      if (!data || !data.quoteId || !Array.isArray(data.options)) {
        throw new Error('GO კალკულატორმა ფასის შეთავაზება ვერ დააბრუნა.')
      }
      this.quoteId = data.quoteId
      const byCode = {}
      data.options.forEach(option => { byCode[option.category_code] = option })
      this.categories = this.categories.map(category => ({
        ...category,
        estimatedFare: byCode[category.code] ? Number(byCode[category.code].total_fare) : null
      }))
      const first = this.categories.find(category => category.estimatedFare !== null)
      if (first) await this.selectCategory(first)
    },
    async selectCategory(category) {
      this.selectedCategory = category.code
      if (!this.quoteId || !supabase) return
      try {
        const { data, error } = await supabase.functions.invoke('quote-route', {
          body: { action: 'select_category', quoteId: this.quoteId, categoryCode: category.code }
        })
        if (error) throw error
        this.selectedFare = data && data.selectedFare !== undefined ? Number(data.selectedFare) : category.estimatedFare
      } catch (error) {
        this.locationError = true
        this.locationMessage = error.message || 'კატეგორიის არჩევა ვერ მოხერხდა.'
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
        const quotePoints = [{
          point_type: 'pickup',
          latitude: this.pickupCoordinates[1],
          longitude: this.pickupCoordinates[0],
          address: this.pickupText
        }]
        this.stops.forEach(stop => quotePoints.push({
          point_type: 'stop',
          latitude: stop.coordinates[1],
          longitude: stop.coordinates[0],
          address: stop.address
        }))
        quotePoints.push({
          point_type: 'dropoff',
          latitude: this.destinationCoordinates[1],
          longitude: this.destinationCoordinates[0],
          address: this.destinationText
        })
        this.routeSummary = await this.$refs.tomtomMap.routeBetween(routePoints)
        await this.createFareQuote(quotePoints)
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
