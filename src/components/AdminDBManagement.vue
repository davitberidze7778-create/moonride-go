<template>
  <v-container fluid class="admin-page">
    <v-row align="center" class="mb-3">
      <v-col cols="12" md="8">
        <div class="overline amber--text text--accent-3">MASTER ADMIN / SYSTEM</div>
        <h1 class="mb-1">Supabase connection checks</h1>
        <div class="caption grey--text">Read-only connectivity and RLS visibility diagnostics</div>
      </v-col>
      <v-col cols="12" md="4" class="text-md-right">
        <v-btn outlined color="amber" :loading="loading" @click="runChecks">Check connections</v-btn>
      </v-col>
    </v-row>

    <v-alert type="info" text dense>
      These checks only request row counts from existing GO tables. They do not insert, update or delete database records.
    </v-alert>
    <v-alert v-if="errorMessage" type="error" dense>{{ errorMessage }}</v-alert>

    <v-row v-if="checks.length">
      <v-col cols="12" sm="4">
        <v-card dark color="#111c2b" outlined class="pa-3">
          <div class="caption grey--text">Readable tables</div>
          <div class="display-1 success--text">{{ readableCount }}</div>
        </v-card>
      </v-col>
      <v-col cols="12" sm="4">
        <v-card dark color="#111c2b" outlined class="pa-3">
          <div class="caption grey--text">Access / query issues</div>
          <div class="display-1 warning--text">{{ issueCount }}</div>
        </v-card>
      </v-col>
      <v-col cols="12" sm="4">
        <v-card dark color="#111c2b" outlined class="pa-3">
          <div class="caption grey--text">Last checked</div>
          <div class="subtitle-1">{{ lastChecked || '—' }}</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card dark color="#111c2b" outlined>
      <v-card-title>GO database table access</v-card-title>
      <v-data-table
        :headers="headers"
        :items="checks"
        :loading="loading"
        :items-per-page="25"
        dark
        class="elevation-0"
      >
        <template v-slot:item.status="{ item }">
          <v-chip x-small :color="item.ok ? 'success' : 'warning'" text-color="white">
            {{ item.ok ? 'Readable' : 'Check required' }}
          </v-chip>
        </template>
        <template v-slot:item.detail="{ item }">
          <span class="caption">{{ item.detail || 'Read permission confirmed' }}</span>
        </template>
        <template v-slot:no-data>
          Press “Check connections” to test read access to existing GO tables.
        </template>
      </v-data-table>
    </v-card>

    <v-alert type="warning" text class="mt-4">
      A readable table does not mean that its business workflow is complete. The current audit has not identified complete ride/order, payment/refund/payout or support-ticket modules. Those must be designed and secured before the related admin controls can work.
    </v-alert>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'AdminDBManagement',
  data() {
    return {
      loading: false,
      errorMessage: '',
      lastChecked: '',
      checks: [],
      tables: [
        'profiles',
        'countries',
        'regions',
        'cities',
        'go_service_zones',
        'driver_profiles',
        'driver_documents',
        'driver_live_locations',
        'vehicles',
        'vehicle_photos',
        'vehicle_ai_inspections',
        'vehicle_categories',
        'vehicle_category_history',
        'vehicle_category_rates',
        'city_vehicle_rates',
        'fare_rules',
        'waiting_fee_rules',
        'ride_quotes',
        'ride_quote_items',
        'ride_route_points',
        'ride_route_legs',
        'go_tariff_plans',
        'go_tariff_category_rates',
        'go_tariff_dynamic_rules',
        'go_tariff_waiting_rules',
        'go_quote_tariff_snapshots',
        'go_tariff_audit_log'
      ],
      headers: [
        { text: 'Table', value: 'table' },
        { text: 'Status', value: 'status' },
        { text: 'Visible rows', value: 'count' },
        { text: 'Details', value: 'detail' }
      ]
    }
  },
  computed: {
    readableCount() {
      return this.checks.filter(item => item.ok).length
    },
    issueCount() {
      return this.checks.filter(item => !item.ok).length
    }
  },
  methods: {
    async runChecks() {
      this.errorMessage = ''
      if (!supabase) {
        this.errorMessage = 'Supabase configuration is missing from this APK build.'
        return
      }
      this.loading = true
      try {
        const results = await Promise.all(this.tables.map(async table => {
          const { count, error } = await supabase
            .from(table)
            .select('*', { count: 'exact', head: true })
          if (error) {
            return {
              table,
              ok: false,
              count: '—',
              detail: (error.code ? error.code + ': ' : '') + error.message
            }
          }
          return {
            table,
            ok: true,
            count: count === null ? '—' : count,
            detail: 'Read permission confirmed'
          }
        }))
        this.checks = results
        this.lastChecked = new Date().toLocaleString()
      } catch (error) {
        this.errorMessage = error.message || 'Unable to complete Supabase connection checks.'
      } finally {
        this.loading = false
      }
    }
  },
  mounted() {
    this.runChecks()
  }
}
</script>

<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
</style>
