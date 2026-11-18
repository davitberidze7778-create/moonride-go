<template>
  <section class="tomtom-map-card" aria-label="რუქა">
    <div class="map-frame">
      <div ref="mapContainer" class="map-canvas"></div>
      <div v-if="!hasApiKey" class="map-message"><strong>რუკა დროებით მიუწვდომელია</strong><span>შეამოწმე ინტერნეტთან კავშირი.</span></div>
      <div v-else-if="mapError" class="map-message"><strong>რუკის ჩატვირთვა ვერ მოხერხდა</strong><span>{{ mapError }}</span></div>
      <div v-else-if="mapLoading" class="map-loading" aria-label="რუქა იტვირთება"><span class="map-spinner"></span></div>
      <div v-if="routeError && mapLoaded" class="map-route-warning">{{ routeError }}</div>
    </div>
  </section>
</template>

<script>
import { TomTomConfig } from '@tomtom-org/maps-sdk/core'
import { TomTomMap, RoutingModule } from '@tomtom-org/maps-sdk/map'
import { reverseGeocode, geocodeOne, calculateRoute } from '@tomtom-org/maps-sdk/services'
import { Marker } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

export default {
  name: 'TomTomMap',
  data() {
    return {
      hasApiKey: Boolean((process.env.VUE_APP_TOMTOM_API_KEY || '').trim()),
      mapLoading: false,
      mapLoaded: false,
      mapError: '',
      mapErrorCode: '',
      routeError: ''
    }
  },
  mounted() {
    this._tomTomMap = null
    this._userMarker = null
    this._routingModule = null
    this._pendingPosition = null
  },
  beforeDestroy() {
    if (this._userMarker) {
      this._userMarker.remove()
      this._userMarker = null
    }
    if (this._tomTomMap && this._tomTomMap.mapLibreMap) {
      this._tomTomMap.mapLibreMap.remove()
      this._tomTomMap = null
    }
  },
  methods: {
    initializeMap(initialPosition) {
      if (!this.hasApiKey) {
        this.mapError = 'რუკა დროებით მიუწვდომელია.'
        return
      }
      const center = Array.isArray(initialPosition) && initialPosition.length === 2
        ? [Number(initialPosition[0]), Number(initialPosition[1])]
        : null
      if (!center || !center.every(Number.isFinite)) return
      this.mapLoading = true
      this.mapError = ''
      this.mapErrorCode = ''
      this.routeError = ''
      try {
        TomTomConfig.instance.put({ apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(), language: 'ngt' })
        this._tomTomMap = new TomTomMap({
          apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(),
          language: 'ngt',
          style: { type: 'standard', id: 'streetDark' },
          mapLibre: { container: this.$refs.mapContainer, center, zoom: 15 }
        })
        const map = this._tomTomMap.mapLibreMap
        map.on('load', () => this.handleMapLoad())
        map.on('error', event => this.handleMapError(event))
      } catch (error) {
        this.mapLoading = false
        this.mapError = 'რუკის შექმნა ვერ მოხერხდა. შეამოწმე TomTom Maps SDK გასაღები და Map Display API წვდომა.'
        this.mapErrorCode = error && error.code ? String(error.code) : 'MAP_INIT'
      }
    },
    async handleMapLoad() {
      this.mapLoaded = true
      this.mapLoading = false
      this.mapError = ''
      this.mapErrorCode = ''
      if (this._pendingPosition) {
        this.applyUserLocation(this._pendingPosition)
        this._pendingPosition = null
      }
      try {
        this._routingModule = await RoutingModule.create(this._tomTomMap)
        this.routeError = ''
      } catch (error) {
        this.routeError = 'მარშრუტის სერვისი დროებით მიუწვდომელია.'
      }
    },
    handleMapError(event) {
      if (this.mapLoaded) return
      this.mapLoading = false
      const error = event && event.error ? event.error : event
      const status = error && (error.status || (error.response && error.response.status))
      const code = error && error.code
      if (status === 401 || status === 403) {
        this.mapError = 'რუკის სერვისი დროებით მიუწვდომელია. სცადე მოგვიანებით.'
      } else if (status === 429) {
        this.mapError = 'რუკა დროებით მიუწვდომელია. სცადე მოგვიანებით.'
      } else {
        this.mapError = 'რუკის ჩატვირთვა ვერ მოხერხდა. შეამოწმე ინტერნეტი.'
      }
      this.mapErrorCode = status ? 'HTTP ' + status : (code ? String(code) : 'MAP_NETWORK')
    },
    setUserLocation(longitude, latitude) {
      const lng = Number(longitude)
      const lat = Number(latitude)
      if (!Number.isFinite(lng) || !Number.isFinite(lat)) return false
      this._pendingPosition = [lng, lat]
      if (!this._tomTomMap) {
        this.initializeMap(this._pendingPosition)
        return Boolean(this._tomTomMap)
      }
      if (this.mapLoaded) {
        this.applyUserLocation(this._pendingPosition)
        this._pendingPosition = null
      }
      return true
    },
    async reverseLookup(longitude, latitude) {
      if (!this.hasApiKey) throw new Error('TomTom API გასაღები მიუწვდომელია.')
      const place = await reverseGeocode({ position: [Number(longitude), Number(latitude)] })
      const address = place && place.properties && place.properties.address
      return address && address.freeformAddress ? address.freeformAddress : 'მისამართი ვერ ამოვიცანით — შეასწორე რუკაზე.'
    },
    async searchAddress(query, bias) {
      if (!this.hasApiKey) throw new Error('TomTom API გასაღები მიუწვდომელია.')
      const place = await geocodeOne({ query: String(query || '').trim(), geoBias: bias ? { position: bias } : undefined })
      const coordinates = place && place.geometry && place.geometry.coordinates
      if (!coordinates || coordinates.length < 2) throw new Error('ამ მისამართისთვის კოორდინატები ვერ მოიძებნა.')
      const address = place.properties && place.properties.address
      return {
        coordinates: [Number(coordinates[0]), Number(coordinates[1])],
        address: address && address.freeformAddress ? address.freeformAddress : String(query).trim()
      }
    },
    async routeBetween(locations) {
      if (!this.mapLoaded || !this._routingModule) throw new Error('TomTom რუკა ჯერ იტვირთება.')
      if (!Array.isArray(locations) || locations.length < 2) throw new Error('მარშრუტისთვის საჭიროა საწყისი და საბოლოო წერტილი.')
      const routes = await calculateRoute({ locations })
      const first = routes && routes.features && routes.features[0]
      if (!first || !first.properties || !first.properties.summary) throw new Error('TomTom-მა მარშრუტი ვერ გამოთვალა.')
      await this._routingModule.showRoutes(routes)
      await this._routingModule.showWaypoints(locations)
      return first.properties.summary
    },
    applyUserLocation(position) {
      const map = this._tomTomMap && this._tomTomMap.mapLibreMap
      if (!map) return
      if (!this._userMarker) {
        this._userMarker = new Marker({ color: '#2F80FF' }).setLngLat(position).addTo(map)
      } else {
        this._userMarker.setLngLat(position)
      }
      map.flyTo({ center: position, zoom: 15, essential: true })
    }
  }
}
</script>

<style scoped>
.tomtom-map-card { margin:0 0 17px; overflow:hidden; border:1px solid rgba(82,145,225,.2); border-radius:17px; background:#102544; }
.map-frame { position:relative; min-height:330px; background:#0B1B32; }
.map-canvas { width:100%; height:330px; min-height:330px; }
.map-message, .map-loading { position:absolute; inset:0; z-index:3; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:9px; padding:24px; background:rgba(8,14,28,.93); color:#aab6cc; text-align:center; font-size:11px; line-height:1.55; }
.map-message strong { color:#48B7FF; font-size:13px; }
.map-message small { color:#8BCBFF; font-size:10px; }
.map-loading { background:rgba(8,14,28,.18); color:#f3f6fc; }
.map-spinner { width:22px; height:22px; border:2px solid rgba(184,217,255,.25); border-top-color:#48B7FF; border-radius:50%; animation:map-spin .8s linear infinite; }
@keyframes map-spin { to { transform:rotate(360deg); } }
.map-route-warning { padding:8px 12px; background:#132D4B; color:#8BCBFF; font-size:10px; line-height:1.45; }
</style>
