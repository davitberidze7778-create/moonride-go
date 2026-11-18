<template>
  <section class="tomtom-map-card" aria-label="TomTom რუკა">
    <div class="map-heading">
      <div><div class="map-eyebrow">MOONRIDEGO</div><div class="map-title">რუკა · ბათუმი</div></div>
      <span class="map-provider">TomTom</span>
    </div>
    <div class="map-frame">
      <div ref="mapContainer" class="map-canvas"></div>
      <div v-if="!hasApiKey" class="map-message">
        <strong>TomTom API გასაღები მიუწვდომელია</strong>
        <span>რუკის გასაშვებად საჭიროა GitHub Actions Secret VUE_APP_TOMTOM_API_KEY.</span>
      </div>
      <div v-else-if="mapError" class="map-message"><strong>რუკის ჩატვირთვა ვერ მოხერხდა</strong><span>{{ mapError }}</span><small v-if="mapErrorCode">კოდი: {{ mapErrorCode }}</small></div>
      <div v-else-if="mapLoading" class="map-loading">TomTom რუკა იტვირთება...</div>
      <div v-if="mapLoaded" class="map-ready"><span class="ready-dot"></span> TOMTOM MAP READY</div>
    </div>
  </section>
</template>

<script>
import { TomTomConfig } from '@tomtom-org/maps-sdk/core'
import { TomTomMap, RoutingModule } from '@tomtom-org/maps-sdk/map'
import { reverseGeocode, geocodeOne, calculateRoute } from '@tomtom-org/maps-sdk/services'
import { Marker } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

const BATUMI_CENTER = [41.6367, 41.6168]

export default {
  name: 'TomTomMap',
  data() {
    return {
      hasApiKey: Boolean((process.env.VUE_APP_TOMTOM_API_KEY || '').trim()),
      mapLoading: false,
      mapLoaded: false,
      mapError: '',
      mapErrorCode: ''
    }
  },
  mounted() {
    this._tomTomMap = null
    this._userMarker = null
    this._routingModule = null
    this._pendingPosition = null
    this.initializeMap()
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
    initializeMap() {
      if (!this.hasApiKey) return
      this.mapLoading = true
      this.mapError = ''
      this.mapErrorCode = ''
      try {
        TomTomConfig.instance.put({ apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(), language: 'ngt' })
        this._tomTomMap = new TomTomMap({
          apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(),
          language: 'ngt',
          style: { type: 'standard', id: 'streetDark' },
          mapLibre: { container: this.$refs.mapContainer, center: BATUMI_CENTER, zoom: 13 }
        })
        const map = this._tomTomMap.mapLibreMap
        map.on('load', () => this.handleMapLoad())
        map.on('error', event => this.handleMapError(event))
      } catch (error) {
        this.mapLoading = false
        this.mapError = 'შეამოწმე ინტერნეტი, API გასაღები და TomTom-ის Map Display API ნებართვა.'
      }
    },
    async handleMapLoad() {
      try {
        this._routingModule = await RoutingModule.create(this._tomTomMap)
        this.mapLoaded = true
        this.mapLoading = false
        this.mapError = ''
        if (this._pendingPosition) {
          this.applyUserLocation(this._pendingPosition)
          this._pendingPosition = null
        }
      } catch (error) {
        this.mapLoading = false
        this.mapError = 'რუკა ჩაიტვირთა, მაგრამ მარშრუტის მოდული ვერ გაეშვა. შეამოწმე Routing API.'
      }
    },
    handleMapError(event) {
      if (this.mapLoaded) return
      this.mapLoading = false
      const error = event && event.error ? event.error : event
      const status = error && (error.status || (error.response && error.response.status))
      const code = error && error.code
      if (status === 401 || status === 403) {
        this.mapError = 'TomTom-მა API გასაღები ან Map Display API წვდომა უარყო. გადაამოწმე Maps SDK for JavaScript პროდუქტი და გასაღების შეზღუდვები.'
      } else if (status === 429) {
        this.mapError = 'TomTom API მოთხოვნების ლიმიტი ამოიწურა. სცადე მოგვიანებით ან გადაამოწმე ტარიფი.'
      } else {
        this.mapError = 'TomTom რუკის სერვერთან კავშირი ვერ შედგა. შეამოწმე ინტერნეტი და Maps SDK for JavaScript API წვდომა.'
      }
      this.mapErrorCode = status ? 'HTTP ' + status : (code ? String(code) : 'MAP_NETWORK')
    },
    setUserLocation(longitude, latitude) {
      const lng = Number(longitude)
      const lat = Number(latitude)
      if (!Number.isFinite(lng) || !Number.isFinite(lat) || !this._tomTomMap) return false
      this._pendingPosition = [lng, lat]
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
.map-heading { display:flex; align-items:center; justify-content:space-between; padding:13px 15px; }
.map-eyebrow { color:#2F80FF; font-size:8px; font-weight:800; letter-spacing:1.7px; }
.map-title { margin-top:3px; color:#f3f6fc; font-size:14px; font-weight:800; }
.map-provider { padding:5px 9px; border:1px solid rgba(47,128,255,.35); border-radius:8px; color:#2F80FF; font-size:10px; font-weight:700; }
.map-frame { position:relative; min-height:330px; background:#0B1B32; }
.map-canvas { width:100%; height:330px; min-height:330px; }
.map-message, .map-loading { position:absolute; inset:0; z-index:3; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:9px; padding:24px; background:rgba(8,14,28,.93); color:#aab6cc; text-align:center; font-size:11px; line-height:1.55; }
.map-message strong { color:#48B7FF; font-size:13px; }
.map-message small { color:#8BCBFF; font-size:10px; }
.map-loading { background:rgba(8,14,28,.55); color:#f3f6fc; }
.map-ready { position:absolute; right:10px; bottom:10px; z-index:2; display:flex; align-items:center; gap:6px; padding:6px 9px; border:1px solid rgba(255,255,255,.12); border-radius:8px; background:rgba(8,14,28,.88); color:#e3e9f5; font-size:9px; font-weight:700; letter-spacing:.4px; }
.ready-dot { width:6px; height:6px; border-radius:50%; background:#2F80FF; box-shadow:0 0 10px rgba(72,183,255,.95); }
</style>
