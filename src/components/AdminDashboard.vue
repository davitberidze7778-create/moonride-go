<template>
  <v-container fluid class="admin-home">
    <v-row align="center" class="mb-4">
      <v-col cols="12" sm="8">
        <div class="overline amber--text text--accent-3">MOONRIDE GO</div>
        <h1 class="display-1 font-weight-bold">MASTER ADMIN</h1>
        <div class="subtitle-2 grey--text">Operations overview</div>
      </v-col>
      <v-col cols="12" sm="4" class="text-sm-right">
        <v-btn outlined color="amber" :loading="loading" @click="loadCounts">Refresh data</v-btn>
      </v-col>
    </v-row>

    <v-alert v-if="errorMessage" type="warning" dense text>{{ errorMessage }}</v-alert>
    <v-row>
      <v-col v-for="metric in metrics" :key="metric.key" cols="12" sm="6" lg="3">
        <v-card dark color="#111c2b" class="metric-card pa-4" outlined>
          <div class="caption grey--text text-uppercase">{{ metric.label }}</div>
          <div class="display-2 font-weight-bold amber--text text--accent-3 mt-2">
            {{ counts[metric.key] === null ? '—' : counts[metric.key] }}
          </div>
          <div class="caption grey--text mt-2">{{ metric.description }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card dark color="#111c2b" outlined class="pa-4 mt-4">
      <div class="title mb-2">System connection</div>
      <v-chip small :color="connected ? 'success' : 'warning'" text-color="white">
        {{ connected ? 'Supabase client configured' : 'Supabase configuration required' }}
      </v-chip>
      <div class="caption grey--text mt-3" v-if="lastUpdated">
        Last refreshed: {{ lastUpdated }}
      </div>
      <div class="caption grey--text mt-2">
        Counts are read from the existing GO database. No database records are changed by this dashboard.
      </div>
    </v-card>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

export default {
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
        rideQuotes: null
      },
      metrics: [
        { key: 'profiles', label: 'Total accounts', description: 'All visible user profiles' },
        { key: 'passengers', label: 'Passengers', description: 'Profiles with passenger role' },
        { key: 'drivers', label: 'Drivers', description: 'Profiles with driver role' },
        { key: 'rideQuotes', label: 'Ride quotes', description: 'Quotes recorded in GO database' }
      ]
    }
  },
  mounted() {
    this.loadCounts()
  },
  methods: {
    async loadCounts() {
      this.errorMessage = ''
      if (!supabase) {
        this.errorMessage = 'Supabase is not configured. Add VUE_APP_SUPABASE_URL and VUE_APP_SUPABASE_ANON_KEY to the build environment.'
        return
      }

      this.loading = true
      try {
        const results = await Promise.all([
          supabase.from('profiles').select('id', { count: 'exact', head: true }),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'passenger'),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'driver'),
          supabase.from('ride_quotes').select('*', { count: 'exact', head: true })
        ])

        const failed = results.find(result => result.error)
        if (failed) throw failed.error

        this.counts.profiles = results[0].count || 0
        this.counts.passengers = results[1].count || 0
        this.counts.drivers = results[2].count || 0
        this.counts.rideQuotes = results[3].count || 0
        this.lastUpdated = new Date().toLocaleString()
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load dashboard counts. Check Supabase RLS policies.'
      } finally {
        this.loading = false
      }
    }
  }
}
</script>

<style scoped>
.admin-home {
  min-height: 100vh;
  background: #080e18;
  color: #f4f6f8;
}
.metric-card {
  min-height: 150px;
  border-color: rgba(255, 193, 7, 0.25);
}
</style>
