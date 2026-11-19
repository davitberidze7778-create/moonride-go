<template>
  <section class="tomtom-map-card" aria-label="რუქა">
    <div class="map-frame">
      <div ref="mapContainer" class="map-canvas"></div>
      <div v-if="!hasApiKey" class="map-message">
        <strong>TomTom რუკის გასაღები არ არის დაყენებული</strong>
        <span>შეამოწმე GitHub Actions-ში VUE_APP_TOMTOM_API_KEY.</span>
      </div>
      <div v-else-if="mapError" class="map-message">
        <strong>რუკის ჩატვირთვა ვერ მოხერხდა</strong>
        <span>{{ mapError }}</span>
        <button type="button" class="map-retry-button" @click.stop="retryMap">ხელახლა ცდა</button>
      </div>
      <div v-else-if="mapLoading" class="map-loading" aria-label="რუქა იტვირთება">
        <span class="map-spinner"></span>
        <span>რუკა იტვირთება...</span>
      </div>
      <div v-if="mapWarning && mapLoaded" class="map-route-warning">{{ mapWarning }}</div>
      <div v-if="routeError && mapLoaded" class="map-route-warning">{{ routeError }}</div>
      <div v-if="mapLoaded" class="map-map-controls" aria-label="რუკის მართვა">
        <button type="button" class="map-action-button map-zoom-button" aria-label="რუკის გადიდება" title="გადიდება" @click.stop="zoomIn">+</button>
        <button type="button" class="map-action-button map-zoom-button" aria-label="რუკის დაპატარავება" title="დაპატარავება" @click.stop="zoomOut">−</button>
        <button type="button" class="map-action-button map-location-button" aria-label="ჩემს მდებარეობაზე დაბრუნება" title="ჩემი მდებარეობა" @click.stop="recenter">
          <span aria-hidden="true">◎</span>
        </button>
      </div>
    </div>
  </section>
</template>

<script>
import { TomTomConfig } from '@tomtom-org/maps-sdk/core'
import { TomTomMap, RoutingModule } from '@tomtom-org/maps-sdk/map'
import { reverseGeocode, geocodeOne, calculateRoute } from '@tomtom-org/maps-sdk/services'
import { Marker, setWorkerUrl } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

// Vue CLI/Webpack must serve MapLibre GL JS v6's module worker explicitly.
setWorkerUrl('/maplibre-gl-worker.mjs')

export default {
  name: 'TomTomMap',
  data() {
    return {
      hasApiKey: Boolean((process.env.VUE_APP_TOMTOM_API_KEY || '').trim()),
      mapLoading: false,
      mapLoaded: false,
      mapError: '',
      mapErrorCode: '',
      mapWarning: '',
      routeError: ''
    }
  },
  mounted() {
    this._tomTomMap = null
    this._userMarker = null
    this._routingModule = null
    this._pendingPosition = null
    this._lastUserPosition = null
    this._resizeObserver = null
    this._resizeFrame = null
    this._lastMapSize = ''
    this._mapLoadHandled = false
    this._boundViewportResize = () => this.scheduleMapResize(true)
    this._boundVisibilityChange = () => {
      if (!document.hidden) this.scheduleMapResize(true)
    }
    window.addEventListener('resize', this._boundViewportResize, { passive: true })
    window.addEventListener('orientationchange', this._boundViewportResize, { passive: true })
    window.addEventListener('pageshow', this._boundViewportResize, { passive: true })
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', this._boundViewportResize, { passive: true })
    }
    document.addEventListener('visibilitychange', this._boundVisibilityChange)
  },
  beforeDestroy() {
    window.removeEventListener('resize', this._boundViewportResize)
    window.removeEventListener('orientationchange', this._boundViewportResize)
    window.removeEventListener('pageshow', this._boundViewportResize)
    if (window.visualViewport) {
      window.visualViewport.removeEventListener('resize', this._boundViewportResize)
    }
    document.removeEventListener('visibilitychange', this._boundVisibilityChange)
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    }
    if (this._resizeFrame !== null && this._resizeFrame !== undefined) {
      window.cancelAnimationFrame(this._resizeFrame)
      this._resizeFrame = null
    }
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
      if (this._tomTomMap) {
        this.scheduleMapResize()
        return
      }
      if (!this.hasApiKey) {
        this.mapError = 'რუკა დროებით მიუწვდომელია.'
        return
      }
      const center = Array.isArray(initialPosition) && initialPosition.length === 2
        ? [Number(initialPosition[0]), Number(initialPosition[1])]
        : null
      if (!center || !center.every(Number.isFinite)) return
      this.mapLoading = true
      this.mapLoaded = false
      this.mapError = ''
      this.mapWarning = ''
      this.mapErrorCode = ''
      this.routeError = ''
      this._mapLoadHandled = false
      try {
        TomTomConfig.instance.put({ apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(), language: 'ngt' })
        this._tomTomMap = new TomTomMap({
          apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(),
          language: 'ngt',
          style: { type: 'standard', id: 'streetDark' },
          mapLibre: {
            container: this.$refs.mapContainer,
            center,
            zoom: 14,
            minZoom: 4,
            maxZoom: 19,
            pitch: 0,
            bearing: 0,
            dragPan: true,
            dragRotate: false,
            scrollZoom: true,
            doubleClickZoom: true,
            touchZoomRotate: true,
            touchPitch: false,
            cooperativeGestures: false,
            maxPitch: 0,
            fadeDuration: 0,
            antialias: false
          }
        })
        const map = this._tomTomMap.mapLibreMap
        map.dragRotate.disable()
        map.touchPitch.disable()
        // Explicitly preserve one-finger drag and two-finger pinch zoom on Android WebView.
        map.dragPan.enable()
        map.touchZoomRotate.enable()
        map.touchZoomRotate.disableRotation()
        map.scrollZoom.enable()
        map.doubleClickZoom.enable()
        map.getCanvas().style.touchAction = 'none'
        if (map.getCanvasContainer) {
          map.getCanvasContainer().style.touchAction = 'none'
        }
        if (typeof ResizeObserver !== 'undefined' && this.$refs.mapContainer) {
          this._resizeObserver = new ResizeObserver(() => this.scheduleMapResize())
          this._resizeObserver.observe(this.$refs.mapContainer)
        }
        const onMapLoad = () => {
          if (this._mapLoadHandled) return
          this._mapLoadHandled = true
          this.handleMapLoad()
        }
        map.once('load', onMapLoad)
        // The SDK loads styles asynchronously, but guard against a style that is
        // already ready before listeners are attached (e.g. WebView restore).
        if (map.loaded && map.loaded()) onMapLoad()
        map.on('error', event => this.handleMapError(event))
      } catch (error) {
        this.mapLoading = false
        this.mapError = 'რუკის ჩატვირთვა ვერ მოხერხდა. შეამოწმე ინტერნეტი და სცადე თავიდან.'
        this.mapErrorCode = error && error.code ? String(error.code) : 'MAP_INIT'
      }
    },
    async handleMapLoad() {
      this.mapLoaded = true
      this.mapLoading = false
      this.mapError = ''
      this.mapWarning = ''
      this.mapErrorCode = ''
      this.scheduleMapResize(true)
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
      const error = event && event.error ? event.error : event
      const status = error && (error.status || (error.response && error.response.status))
      const code = error && error.code
      const detail = error && (error.message || error.cause && error.cause.message)
      const friendly = status === 401 || status === 403
        ? 'TomTom რუკის ავტორიზაცია ვერ მოხერხდა. შეამოწმე რუკის API key.'
        : status === 429
          ? 'რუკის მოთხოვნების ლიმიტი დროებით ამოიწურა.'
          : 'რუკის მონაცემების ჩატვირთვა შეფერხდა. შეამოწმე ინტერნეტი.'
      if (this.mapLoaded) {
        // A late tile/network error must not cover an otherwise interactive map.
        this.mapWarning = friendly
      } else {
        this.mapLoading = false
        this.mapError = friendly
      }
      this.mapErrorCode = status ? 'HTTP ' + status : (code ? String(code) : (detail ? String(detail).slice(0, 90) : 'MAP_NETWORK'))
    },
    setUserLocation(longitude, latitude) {
      const lng = Number(longitude)
      const lat = Number(latitude)
      if (!Number.isFinite(lng) || !Number.isFinite(lat)) return false
      this._pendingPosition = [lng, lat]
      this._lastUserPosition = [lng, lat]
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
      if (!this.hasApiKey) throw new Error('რუკა დროებით მიუწვდომელია.')
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
      if (!this.mapLoaded || !this._routingModule) throw new Error('რუკა ჯერ იტვირთება. სცადე ხელახლა.')
      if (!Array.isArray(locations) || locations.length < 2) throw new Error('მარშრუტისთვის საჭიროა საწყისი და საბოლოო წერტილი.')
      const routes = await calculateRoute({ locations })
      const first = routes && routes.features && routes.features[0]
      if (!first || !first.properties || !first.properties.summary) throw new Error('მარშრუტი ვერ გამოითვალა. გადაამოწმე მისამართები.')
      await this._routingModule.showRoutes(routes)
      await this._routingModule.showWaypoints(locations)
      return first.properties.summary
    },
    scheduleMapResize(force) {
      if (!this._tomTomMap || !this._tomTomMap.mapLibreMap || this._resizeFrame !== null) return
      this._resizeFrame = window.requestAnimationFrame(() => {
        this._resizeFrame = null
        const map = this._tomTomMap && this._tomTomMap.mapLibreMap
        const container = this.$refs.mapContainer
        if (!map || !container || document.hidden) return
        const width = Math.round(container.clientWidth)
        const height = Math.round(container.clientHeight)
        if (!width || !height) return
        const size = width + 'x' + height
        if (force || size !== this._lastMapSize) {
          this._lastMapSize = size
          map.resize()
        }
        // WebView can suspend WebGL while the app is backgrounded.
        if (typeof map.triggerRepaint === 'function') map.triggerRepaint()
      })
    },
    zoomIn() {
      const map = this._tomTomMap && this._tomTomMap.mapLibreMap
      if (!map || !this.mapLoaded) return
      map.zoomIn({ duration: 160 })
    },
    zoomOut() {
      const map = this._tomTomMap && this._tomTomMap.mapLibreMap
      if (!map || !this.mapLoaded) return
      map.zoomOut({ duration: 160 })
    },
    retryMap() {
      const position = this._lastUserPosition || this._pendingPosition
      if (this._userMarker) {
        this._userMarker.remove()
        this._userMarker = null
      }
      if (this._tomTomMap && this._tomTomMap.mapLibreMap) {
        this._tomTomMap.mapLibreMap.remove()
      }
      this._tomTomMap = null
      this._routingModule = null
      this._mapLoadHandled = false
      this.mapLoaded = false
      this.mapLoading = false
      this.mapError = ''
      this.mapWarning = ''
      this._lastMapSize = ''
      if (position) this.initializeMap(position)
    },
    recenter() {
      if (!this._lastUserPosition) return
      this.applyUserLocation(this._lastUserPosition)
    },
    applyUserLocation(position) {
      const map = this._tomTomMap && this._tomTomMap.mapLibreMap
      if (!map) return
      this._lastUserPosition = position.slice()
      if (!this._userMarker) {
        this._userMarker = new Marker({ color: '#742BFF' }).setLngLat(position).addTo(map)
      } else {
        this._userMarker.setLngLat(position)
      }
      map.easeTo({ center: position, zoom: 15, duration: 450, essential: true })
      this.scheduleMapResize()
    }
  }
}
</script>

<style scoped>
.tomtom-map-card { margin:0 0 17px; overflow:hidden; border:1px solid rgba(82,145,225,.2); border-radius:17px; background:#102544; }
.map-frame { position:relative; min-height:330px; background:#0B1B32; touch-action:none; overscroll-behavior:contain; }
.map-canvas { width:100%; height:330px; min-height:330px; touch-action:none; overscroll-behavior:contain; }
.map-message, .map-loading { position:absolute; inset:0; z-index:3; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:9px; padding:24px; background:rgba(8,14,28,.93); color:#aab6cc; text-align:center; font-size:11px; line-height:1.55; }
.map-message strong { color:#A56BFF; font-size:13px; }
.map-retry-button { margin-top:8px; padding:10px 16px; border:1px solid rgba(184,217,255,.35); border-radius:10px; background:#203b60; color:#fff; font-size:11px; font-weight:800; }
.map-message small { color:#C49BFF; font-size:10px; }
.map-loading { background:rgba(8,14,28,.18); color:#f3f6fc; }
.map-spinner { width:22px; height:22px; border:2px solid rgba(184,217,255,.25); border-top-color:#A56BFF; border-radius:50%; animation:map-spin .8s linear infinite; }
@keyframes map-spin { to { transform:rotate(360deg); } }
.map-route-warning { padding:8px 12px; background:#132D4B; color:#C49BFF; font-size:10px; line-height:1.45; }
.map-map-controls { position:absolute; z-index:5; right:12px; bottom:14px; display:flex; flex-direction:column; gap:7px; }
.map-action-button { width:42px; height:42px; display:flex; align-items:center; justify-content:center; border:1px solid rgba(184,217,255,.3); border-radius:12px; background:rgba(7,21,43,.94); color:#fff; font-size:25px; line-height:1; font-weight:600; box-shadow:0 3px 14px rgba(0,0,0,.32); touch-action:manipulation; }
.map-action-button:active { background:#263e63; transform:scale(.97); }
.map-location-button { color:#A56BFF; font-size:23px; }
.map-zoom-button { color:#f1f5ff; font-size:28px; font-weight:500; line-height:1; }
.tomtom-map-card >>> .maplibregl-canvas,
.tomtom-map-card >>> .maplibregl-canvas-container { touch-action:none !important; }
</style>
