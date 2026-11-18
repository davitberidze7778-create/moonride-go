<template>
  <v-container fluid class="dashboard-page pa-4 pa-md-6">
    <div class="dashboard-heading">
      <div>
        <div class="eyebrow">MOONRIDE GO / OVERVIEW</div>
        <h1>Fleet Management Dashboard</h1>
        <p>Live operational data from the connected GO database</p>
      </div>
      <v-btn outlined color="blue lighten-2" :loading="loading" @click="loadCounts">
        <v-icon left small>mdi-refresh</v-icon> Refresh
      </v-btn>
    </div>

    <v-alert v-if="errorMessage" type="warning" dense text class="mb-4">
      {{ errorMessage }}
    </v-alert>

    <v-row>
      <v-col v-for="metric in primaryMetrics" :key="metric.key" cols="12" sm="6" xl="3">
        <v-card dark outlined class="metric-card" :class="'metric-' + metric.theme">
          <div class="metric-top">
            <div class="metric-icon"><v-icon large>{{ metric.icon }}</v-icon></div>
            <span class="metric-label">{{ metric.label }}</span>
          </div>
          <div class="metric-value">{{ formatCount(counts[metric.key]) }}</div>
          <div class="metric-foot">{{ metric.description }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <v-col cols="12" lg="8">
        <v-card dark outlined class="panel-card h-100">
          <div class="panel-heading">
            <div>
              <div class="panel-title"><v-icon color="blue lighten-2" left>mdi-chart-line</v-icon>Operations Overview</div>
              <div class="panel-subtitle">Verified totals from the current database connection</div>
            </div>
            <v-chip small color="blue darken-3" text-color="white">GO DATA</v-chip>
          </div>
          <v-divider class="panel-divider" />
          <v-row class="px-2 py-3">
            <v-col cols="12" sm="6">
              <div class="summary-label">Pending driver applications</div>
              <div class="summary-number">{{ formatCount(counts.pendingDrivers) }}</div>
              <v-chip x-small color="orange darken-3" text-color="white">Awaiting review</v-chip>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="summary-label">Vehicles awaiting review</div>
              <div class="summary-number">{{ formatCount(counts.pendingVehicles) }}</div>
              <v-chip x-small color="orange darken-3" text-color="white">Awaiting review</v-chip>
            </v-col>
          </v-row>
          <v-divider class="panel-divider" />
          <div class="panel-note">
            <v-icon small color="blue lighten-2" class="mr-2">mdi-information-outline</v-icon>
            Ride quotes are price offers, not confirmed rides. The final Rides dashboard will use the verified order lifecycle rather than counting quotes as trips.
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card dark outlined class="panel-card h-100">
          <div class="panel-heading">
            <div>
              <div class="panel-title"><v-icon color="cyan lighten-2" left>mdi-map-outline</v-icon>Live Map</div>
              <div class="panel-subtitle">Driver tracking and active trips</div>
            </div>
            <v-chip small color="orange darken-3" text-color="white">SETUP REQUIRED</v-chip>
          </div>
          <div class="map-placeholder">
            <v-icon size="48" color="blue lighten-2">mdi-map-marker-radius-outline</v-icon>
            <div class="map-placeholder-title">2GIS integration is next</div>
            <div class="map-placeholder-copy">No simulated driver positions are shown. The map will display only verified online-driver locations and active rides after secure access is connected.</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-1">
      <v-col cols="12" md="4">
        <v-card dark outlined class="panel-card h-100">
          <div class="panel-title mb-3"><v-icon left color="amber">mdi-flash</v-icon>Quick Actions</div>
          <v-btn block color="blue darken-2" class="action-button" to="/adminAllDrivers"><v-icon left>mdi-car-multiple</v-icon>Review Drivers</v-btn>
          <v-btn block color="green darken-3" class="action-button" to="/adminVehicles"><v-icon left>mdi-car-side</v-icon>View Vehicles</v-btn>
          <v-btn block color="indigo darken-2" class="action-button" to="/adminAllClients"><v-icon left>mdi-account-group</v-icon>View Passengers</v-btn>
          <v-btn block color="blue-grey darken-2" class="action-button" to="/adminActivity"><v-icon left>mdi-format-list-bulleted</v-icon>Open Ride Quotes</v-btn>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card dark outlined class="panel-card h-100">
          <div class="panel-title mb-3"><v-icon left color="purple lighten-2">mdi-database-check-outline</v-icon>Database Connection</div>
          <div class="health-row">
            <span>Supabase client</span>
            <v-chip x-small :color="connected ? 'success' : 'error'" text-color="white">{{ connected ? 'Configured' : 'Unavailable' }}</v-chip>
          </div>
          <div class="health-row">
            <span>GO profiles</span><strong>{{ formatCount(counts.profiles) }}</strong>
          </div>
          <div class="health-row">
            <span>Registered vehicles</span><strong>{{ formatCount(counts.vehicles) }}</strong>
          </div>
          <div class="health-row">
            <span>Ride quotes</span><strong>{{ formatCount(counts.rideQuotes) }}</strong>
          </div>
          <div class="caption grey--text mt-4" v-if="lastUpdated">Last successful refresh: {{ lastUpdated }}</div>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card dark outlined class="panel-card h-100">
          <div class="panel-title mb-3"><v-icon left color="amber">mdi-shield-check-outline</v-icon>Security & Next Modules</div>
          <div class="next-row"><v-icon small color="success">mdi-check-circle</v-icon><span>Supabase authentication</span></div>
          <div class="next-row"><v-icon small color="success">mdi-check-circle</v-icon><span>Existing GO data read access</span></div>
          <div class="next-row"><v-icon small color="warning">mdi-progress-clock</v-icon><span>Multi-role permissions</span></div>
          <div class="next-row"><v-icon small color="warning">mdi-progress-clock</v-icon><span>Orders, finance and support backend</span></div>
          <div class="next-row"><v-icon small color="warning">mdi-progress-clock</v-icon><span>2GIS Live Map connection</span></div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'AdminDashboard',
  data() {
    return {
      loading: false,
      connected: !!supabase,
      errorMessage: '',
      lastUpdated: '',
      counts: {
        profiles: null,
        passengers: null,
        drivers: null,
        vehicles: null,
        pendingDrivers: null,
        pendingVehicles: null,
        rideQuotes: null
      },
      primaryMetrics: [
        { key: 'drivers', label: 'Total Drivers', icon: 'mdi-car-multiple', theme: 'blue', description: 'Registered driver accounts' },
        { key: 'passengers', label: 'Total Passengers', icon: 'mdi-account-group', theme: 'green', description: 'Registered passenger accounts' },
        { key: 'vehicles', label: 'Registered Vehicles', icon: 'mdi-car-side', theme: 'purple', description: 'Vehicles in the GO database' },
        { key: 'rideQuotes', label: 'Ride Quotes', icon: 'mdi-file-document-outline', theme: 'gold', description: 'Price offers — not confirmed rides' }
      ]
    }
  },
  mounted() {
    this.loadCounts()
  },
  methods: {
    formatCount(value) {
      return value === null || value === undefined ? '—' : Number(value).toLocaleString()
    },
    async loadCounts() {
      this.errorMessage = ''
      if (!supabase) {
        this.connected = false
        this.errorMessage = 'Supabase is not configured. Add the public VUE_APP_SUPABASE_URL and VUE_APP_SUPABASE_ANON_KEY build secrets.'
        return
      }

      this.loading = true
      try {
        const results = await Promise.all([
          supabase.from('profiles').select('id', { count: 'exact', head: true }),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'passenger'),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'driver'),
          supabase.from('vehicles').select('id', { count: 'exact', head: true }),
          supabase.from('driver_profiles').select('user_id', { count: 'exact', head: true }).eq('approval_status', 'pending'),
          supabase.from('vehicles').select('id', { count: 'exact', head: true }).eq('approval_status', 'pending'),
          supabase.from('ride_quotes').select('id', { count: 'exact', head: true })
        ])

        const failed = results.find(result => result.error)
        if (failed) throw failed.error

        this.counts.profiles = results[0].count || 0
        this.counts.passengers = results[1].count || 0
        this.counts.drivers = results[2].count || 0
        this.counts.vehicles = results[3].count || 0
        this.counts.pendingDrivers = results[4].count || 0
        this.counts.pendingVehicles = results[5].count || 0
        this.counts.rideQuotes = results[6].count || 0
        this.connected = true
        this.lastUpdated = new Date().toLocaleString()
      } catch (error) {
        this.connected = false
        this.errorMessage = error.message || 'Unable to load dashboard data. Check the Supabase connection and RLS policies.'
      } finally {
        this.loading = false
      }
    }
  }
}
</script>

<style scoped>
.dashboard-page { min-height: 100vh; background: transparent; color: #f5f7ff; }
.dashboard-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; margin-bottom: 22px; }
.dashboard-heading h1 { color: #f5f7ff; font-size: 27px; font-weight: 800; letter-spacing: -.6px; margin: 3px 0 4px; }
.dashboard-heading p { color: #8fa0bd; font-size: 13px; margin: 0; }
.eyebrow { color: #6daeff; font-size: 10px; font-weight: 800; letter-spacing: 1.8px; }
.metric-card { min-height: 158px; padding: 18px 19px; border-radius: 14px !important; background: #0d172b !important; border-color: rgba(111, 142, 199, .25) !important; }
.metric-top { display: flex; align-items: center; gap: 12px; }
.metric-icon { display: flex; align-items: center; justify-content: center; width: 42px; height: 42px; border-radius: 12px; }
.metric-label { color: #dbe5f7; font-size: 13px; font-weight: 700; }
.metric-value { color: #f5f7ff; font-size: 31px; font-weight: 800; line-height: 1.25; margin: 13px 0 5px; }
.metric-foot { color: #8192ae; font-size: 11px; }
.metric-blue { border-top: 2px solid #2585ff !important; }
.metric-blue .metric-icon { background: rgba(37, 133, 255, .15); color: #55a8ff; }
.metric-green { border-top: 2px solid #19b987 !important; }
.metric-green .metric-icon { background: rgba(25, 185, 135, .15); color: #31d5a4; }
.metric-purple { border-top: 2px solid #8c61e8 !important; }
.metric-purple .metric-icon { background: rgba(140, 97, 232, .15); color: #b18cff; }
.metric-gold { border-top: 2px solid #d99a16 !important; }
.metric-gold .metric-icon { background: rgba(217, 154, 22, .15); color: #f6c94e; }
.panel-card { height: 100%; padding: 19px; border-radius: 14px !important; background: rgba(13, 23, 43, .94) !important; border-color: rgba(111, 142, 199, .23) !important; }
.panel-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
.panel-title { color: #eff4ff; font-size: 15px; font-weight: 800; display: flex; align-items: center; }
.panel-subtitle { color: #8192ae; font-size: 11px; margin: 5px 0 0 30px; }
.panel-divider { border-color: rgba(111, 142, 199, .18) !important; margin-top: 15px; }
.summary-label { color: #98a8c1; font-size: 12px; }
.summary-number { color: #f5f7ff; font-size: 32px; font-weight: 800; margin: 6px 0 8px; }
.panel-note { display: flex; align-items: flex-start; color: #92a3be; font-size: 11px; line-height: 1.5; padding: 14px 6px 2px; }
.map-placeholder { min-height: 240px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; padding: 20px; background: radial-gradient(circle at center, rgba(37, 99, 235, .13), transparent 65%); }
.map-placeholder-title { color: #eaf1ff; font-size: 14px; font-weight: 800; margin-top: 12px; }
.map-placeholder-copy { color: #8798b5; font-size: 11px; line-height: 1.55; max-width: 320px; margin-top: 7px; }
.action-button { margin: 9px 0; height: 42px !important; justify-content: flex-start; }
.health-row { display: flex; justify-content: space-between; align-items: center; gap: 12px; color: #9eacc4; font-size: 12px; padding: 10px 0; border-bottom: 1px solid rgba(111, 142, 199, .12); }
.health-row strong { color: #f0f4fc; font-size: 13px; }
.next-row { display: flex; align-items: center; gap: 9px; color: #aab8cf; font-size: 11px; padding: 8px 0; }
@media (max-width: 600px) {
  .dashboard-page { padding: 14px !important; }
  .dashboard-heading { align-items: flex-start; flex-direction: column; }
  .dashboard-heading h1 { font-size: 22px; }
  .metric-card { min-height: 142px; }
}
</style>