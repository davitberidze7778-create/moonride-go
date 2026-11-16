<template>
  <v-container fluid class="admin-page">
    <v-row align="center" class="mb-3">
      <v-col cols="12" md="7">
        <div class="overline amber--text text--accent-3">MASTER ADMIN / ACTIVITY</div>
        <h1 class="mb-1">Activity / Price Quotes</h1>
        <div class="caption grey--text">Live read-only view of GO fare quote records</div>
      </v-col>
      <v-col cols="12" md="5" class="text-md-right">
        <v-chip color="#263548" text-color="white" class="mr-2">Total: {{ totalItems }}</v-chip>
        <v-btn small outlined color="amber" :loading="loading" @click="loadQuotes">Refresh</v-btn>
      </v-col>
    </v-row>

    <v-alert type="warning" text dense>
      These records are price quotes, not confirmed rides. The complete ride/order lifecycle and driver assignment are not yet available in the verified database schema.
    </v-alert>
    <v-alert v-if="errorMessage" type="error" dense>{{ errorMessage }}</v-alert>

    <v-card dark color="#111c2b" outlined>
      <v-card-title>
        GO price quotes
        <v-spacer></v-spacer>
        <v-text-field
          v-model="search"
          append-icon="mdi-magnify"
          label="Search this page by passenger, quote ID or status"
          single-line
          hide-details
          clearable
          dense
          outlined
          style="max-width: 360px"
        />
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="filteredItems"
        :loading="loading"
        :items-per-page="itemsPerPage"
        :hide-default-footer="true"
        dark
        class="elevation-0"
      >
        <template v-slot:item.selected_fare="{ item }">
          {{ item.selected_fare === null || item.selected_fare === undefined ? '—' : Number(item.selected_fare).toFixed(2) + ' ' + (item.currency_code || '') }}
        </template>
        <template v-slot:item.status="{ item }">
          <v-chip x-small :color="statusColor(item.status)" text-color="white">{{ item.status || 'unknown' }}</v-chip>
        </template>
        <template v-slot:item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
        <template v-slot:item.actions="{ item }">
          <v-btn small text color="amber" @click="openQuote(item)">Details</v-btn>
        </template>
        <template v-slot:no-data>No GO price quote records found or access is restricted by RLS.</template>
      </v-data-table>
      <div class="d-flex align-center justify-center pa-3" v-if="pageCount > 1">
        <v-pagination v-model="page" :length="pageCount" :total-visible="5" color="amber" @input="loadQuotes" />
      </div>
    </v-card>

    <v-dialog v-model="detailsDialog" max-width="650">
      <v-card dark color="#111c2b" v-if="selectedQuote">
        <v-card-title>
          Price quote details
          <v-spacer></v-spacer>
          <v-btn icon @click="detailsDialog = false"><v-icon>mdi-close</v-icon></v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row>
            <v-col cols="12" sm="6"><div class="caption grey--text">Quote status</div><div>{{ selectedQuote.status || '—' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Source</div><div>{{ selectedQuote.quote_source || '—' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Quoted fare</div><div>{{ selectedQuote.selected_fare === null ? '—' : selectedQuote.selected_fare + ' ' + selectedQuote.currency_code }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Distance / duration</div><div>{{ selectedQuote.total_distance_km || '—' }} km / {{ selectedQuote.total_duration_minutes || '—' }} min</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Passenger</div><div>{{ selectedQuote.passenger_name || selectedQuote.passenger_email || selectedQuote.passenger_id }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">City ID</div><div>{{ selectedQuote.city_id || '—' }}</div></v-col>
            <v-col cols="12"><div class="caption grey--text">Quote ID</div><div class="user-id">{{ selectedQuote.id }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Created</div><div>{{ formatDate(selectedQuote.created_at) }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Expires</div><div>{{ formatDate(selectedQuote.expires_at) }}</div></v-col>
          </v-row>
          <v-alert dense text type="info" class="mt-3 mb-0">
            No driver is assigned in this quote record. Do not treat this entry as a booked or completed ride.
          </v-alert>
        </v-card-text>
        <v-card-actions><v-spacer /><v-btn text color="amber" @click="detailsDialog = false">Close</v-btn></v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'AdminActivity',
  data() {
    return {
      loading: false,
      errorMessage: '',
      search: '',
      items: [],
      totalItems: 0,
      page: 1,
      itemsPerPage: 25,
      detailsDialog: false,
      selectedQuote: null,
      headers: [
        { text: 'Created', value: 'created_at' },
        { text: 'Passenger', value: 'passenger_name' },
        { text: 'Fare', value: 'selected_fare' },
        { text: 'Distance (km)', value: 'total_distance_km' },
        { text: 'Status', value: 'status' },
        { text: 'Source', value: 'quote_source' },
        { text: 'Details', value: 'actions', sortable: false }
      ]
    }
  },
  computed: {
    pageCount() {
      return Math.max(1, Math.ceil(this.totalItems / this.itemsPerPage))
    },
    filteredItems() {
      const term = (this.search || '').trim().toLowerCase()
      if (!term) return this.items
      return this.items.filter(item =>
        [item.id, item.passenger_name, item.passenger_email, item.status, item.quote_source]
          .some(value => String(value || '').toLowerCase().includes(term))
      )
    }
  },
  mounted() {
    this.loadQuotes()
  },
  methods: {
    formatDate(value) {
      return value ? new Date(value).toLocaleString() : '—'
    },
    statusColor(status) {
      if (status === 'priced' || status === 'confirmed') return 'success'
      if (status === 'pending') return 'warning'
      if (status === 'expired' || status === 'cancelled') return 'grey'
      return 'primary'
    },
    openQuote(quote) {
      this.selectedQuote = quote
      this.detailsDialog = true
    },
    async loadQuotes() {
      this.loading = true
      this.errorMessage = ''
      try {
        if (!supabase) throw new Error('Supabase configuration is missing.')
        const from = (this.page - 1) * this.itemsPerPage
        const to = from + this.itemsPerPage - 1
        const { data: quotes, count, error } = await supabase
          .from('ride_quotes')
          .select('id, passenger_id, city_id, currency_code, total_distance_km, total_duration_minutes, selected_fare, status, quote_source, created_at, expires_at', { count: 'exact' })
          .order('created_at', { ascending: false })
          .range(from, to)
        if (error) throw error
        this.totalItems = count || 0

        const passengerIds = Array.from(new Set((quotes || []).map(quote => quote.passenger_id).filter(Boolean)))
        let passengerMap = {}
        if (passengerIds.length) {
          const { data: passengers, error: passengerError } = await supabase
            .from('profiles')
            .select('id, full_name, email')
            .in('id', passengerIds)
          if (passengerError) throw passengerError
          passengerMap = (passengers || []).reduce((result, passenger) => {
            result[passenger.id] = passenger
            return result
          }, {})
        }

        this.items = (quotes || []).map(quote => ({
          ...quote,
          passenger_name: passengerMap[quote.passenger_id] ? passengerMap[quote.passenger_id].full_name : '',
          passenger_email: passengerMap[quote.passenger_id] ? passengerMap[quote.passenger_id].email : ''
        }))
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load GO price quote records.'
      } finally {
        this.loading = false
      }
    }
  }
}
</script>

<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
.user-id { overflow-wrap: anywhere; }
</style>
