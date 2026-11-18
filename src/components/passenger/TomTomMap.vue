<template>
  <section class="tomtom-map-card" aria-label="TomTom რუკა">
    <div class="map-heading">
      <div>
        <div class="map-eyebrow">MOONRIDEGO</div>
        <div class="map-title">რუკა · ბათუმი</div>
      </div>
      <span class="map-provider">TomTom</span>
    </div>

    <div class="map-frame">
      <div ref="mapContainer" class="map-canvas"></div>

      <div v-if="!hasApiKey" class="map-message">
        <strong>TomTom გასაღები დასამატებელია</strong>
        <span>GitHub Actions-ის Secret-ში დაამატე VUE_APP_TOMTOM_API_KEY. რუკა ჩაიტვირთება შემდეგ APK-ში.</span>
      </div>

      <div v-else-if="mapError" class="map-message">
        <strong>რუკის ჩატვირთვა ვერ მოხერხდა</strong>
        <span>{{ mapError }}</span>
      </div>

      <div v-else-if="mapLoading" class="map-loading">
        TomTom რუკა იტვირთება...
      </div>

      <div v-if="mapLoaded" class="map-ready">
        <span class="ready-dot"></span>
        TomTom · LIVE MAP
      </div>
    </div>
  </section>
</template>

<script>
import { TomTomConfig } from '@tomtom-org/maps-sdk/core'
import { TomTomMap } from '@tomtom-org/maps-sdk/map'
import { Marker } from 'maplibre-gl'

const BATUMI_CENTER = [41.63, 41.64]

export default {
  name: 'TomTomMap',
  data() {
    return {
      hasApiKey: Boolean((process.env.VUE_APP_TOMTOM_API_KEY || '').trim()),
      mapLoading: false,
      mapLoaded: false,
      mapError: ''
    }
  },
  mounted() {
    this._tomTomMap = null
    this._userMarker = null
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

      try {
        TomTomConfig.instance.put({
          apiKey: process.env.VUE_APP_TOMTOM_API_KEY.trim(),
          language: 'ngt'
        })

        this._tomTomMap = new TomTomMap({
          mapLibre: {
            container: this.$refs.mapContainer,
            center: BATUMI_CENTER,
            zoom: 13
          },
          style: 'standardDark'
        })

        const map = this._tomTomMap.mapLibreMap
        map.on('load', this.handleMapLoad)
        map.on('error', this.handleMapError)
      } catch (error) {
        this.mapLoading = false
        this.mapError = 'შეამოწმე API გასაღები, ინტერნეტი და TomTom-ის API უფლებები.'
      }
    },

    handleMapLoad() {
      this.mapLoaded = true
      this.mapLoading = false
      this.mapError = ''

      if (this._pendingPosition) {
        this.applyUserLocation(this._pendingPosition)
        this._pendingPosition = null
      }
    },

    handleMapError() {
      if (!this.mapLoaded) {
        this.mapLoading = false
        this.mapError = 'შეამოწმე API გასაღები, ინტერნეტი და TomTom-ის API უფლებები.'
      }
    },

    setUserLocation(longitude, latitude) {
      const lng = Number(longitude)
      const lat = Number(latitude)

      if (!Number.isFinite(lng) || !Number.isFinite(lat)) return false
      if (!this._tomTomMap) return false

      this._pendingPosition = [lng, lat]

      if (this.mapLoaded) {
        this.applyUserLocation(this._pendingPosition)
        this._pendingPosition = null
      }

      return true
    },

    applyUserLocation(position) {
      const map = this._tomTomMap && this._tomTomMap.mapLibreMap
      if (!map) return

      if (!this._userMarker) {
        this._userMarker = new Marker({ color: '#f5bd18' })
      }

      this._userMarker.setLngLat(position).addTo(map)
      map.flyTo({
        center: position,
        zoom: 15,
        essential: true
      })
    }
  }
}
</script>

<style scoped>
.tomtom-map-card {
  margin: 0 0 17px;
  overflow: hidden;
  border: 1px solid rgba(132, 154, 192, .2);
  border-radius: 17px;
  background: #111b2e;
}
.map-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 13px 15px;
}
.map-eyebrow {
  color: #f5bd18;
  font-size: 8px;
  font-weight: 800;
  letter-spacing: 1.7px;
}
.map-title {
  margin-top: 3px;
  color: #f3f6fc;
  font-size: 14px;
  font-weight: 800;
}
.map-provider {
  padding: 5px 9px;
  border: 1px solid rgba(245, 189, 24, .35);
  border-radius: 8px;
  color: #f5bd18;
  font-size: 10px;
  font-weight: 700;
}
.map-frame {
  position: relative;
  min-height: 330px;
  background: #0a1425;
}
.map-canvas {
  width: 100%;
  height: 330px;
  min-height: 330px;
}
.map-message,
.map-loading {
  position: absolute;
  inset: 0;
  z-index: 3;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 9px;
  padding: 24px;
  background: rgba(8, 14, 28, .93);
  color: #aab6cc;
  text-align: center;
  font-size: 11px;
  line-height: 1.55;
}
.map-message strong {
  color: #f5bd18;
  font-size: 13px;
}
.map-loading {
  background: rgba(8, 14, 28, .55);
  color: #f3f6fc;
}
.map-ready {
  position: absolute;
  right: 10px;
  bottom: 10px;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 9px;
  border: 1px solid rgba(255, 255, 255, .12);
  border-radius: 8px;
  background: rgba(8, 14, 28, .88);
  color: #e3e9f5;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: .4px;
}
.ready-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #f5bd18;
  box-shadow: 0 0 8px rgba(245, 189, 24, .7);
}
</style>
