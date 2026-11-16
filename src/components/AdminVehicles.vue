<template>
  <v-container fluid class="admin-page">
    <v-row align="center" class="mb-3">
      <v-col cols="12" md="7">
        <div class="overline amber--text text--accent-3">MASTER ADMIN / FLEET</div>
        <h1 class="mb-1">Vehicles</h1>
        <div class="caption grey--text">Vehicles registered by GO drivers</div>
      </v-col>
      <v-col cols="12" md="5" class="text-md-right">
        <v-chip color="#263548" text-color="white" class="mr-2">Total: {{ totalItems }}</v-chip>
        <v-btn small outlined color="amber" :loading="loading" @click="loadItems">Refresh</v-btn>
      </v-col>
    </v-row>

    <v-alert v-if="errorMessage" type="warning" dense>{{ errorMessage }}</v-alert>
    <v-card dark color="#111c2b" outlined>
      <v-card-title>
        Registered vehicles
        <v-spacer></v-spacer>
        <v-text-field
          v-model="search"
          append-icon="mdi-magnify"
          label="Search this page"
          single-line
          hide-details
          clearable
          dense
          outlined
          style="max-width: 300px"
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
        <template v-slot:item.approval_status="{ item }">
          <v-chip x-small :color="statusColor(item.approval_status)" text-color="white">
            {{ item.approval_status || 'unknown' }}
          </v-chip>
        </template>
        <template v-slot:item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
        <template v-slot:item.actions="{ item }">
          <v-btn small text color="amber" @click="openVehicle(item)">View</v-btn>
        </template>
        <template v-slot:no-data>No vehicles found or access is restricted by database policies.</template>
        <template v-slot:no-results>No vehicles on this page match the search.</template>
      </v-data-table>
      <div class="d-flex align-center justify-center pa-3" v-if="pageCount > 1">
        <v-pagination v-model="page" :length="pageCount" :total-visible="5" color="amber" @input="loadItems" />
      </div>
    </v-card>

    <v-dialog v-model="detailsDialog" max-width="650">
      <v-card dark color="#111c2b" v-if="selectedVehicle">
        <v-card-title>
          Vehicle details
          <v-spacer></v-spacer>
          <v-btn icon @click="detailsDialog = false"><v-icon>mdi-close</v-icon></v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row>
            <v-col cols="12" sm="6"><div class="caption grey--text">Make / model</div><div>{{ selectedVehicle.make || '—' }} {{ selectedVehicle.model || '' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Year / color</div><div>{{ selectedVehicle.year || '—' }} / {{ selectedVehicle.color || '—' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Plate number</div><div>{{ selectedVehicle.plate_number || '—' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Passenger capacity</div><div>{{ selectedVehicle.passenger_capacity || '—' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Category code</div><div>{{ selectedVehicle.category_code || '—' }}</div></v-col>
            <v-col cols="12" sm="6"><div class="caption grey--text">Approval status</div><div>{{ selectedVehicle.approval_status || '—' }}</div></v-col>
            <v-col cols="12"><div class="caption grey--text">Owner</div><div>{{ selectedVehicle.owner_name || '—' }}</div><div class="caption grey--text user-id">{{ selectedVehicle.owner_user_id }}</div></v-col>
            <v-col cols="12"><div class="caption grey--text">Vehicle ID</div><div class="user-id">{{ selectedVehicle.id }}</div></v-col>
            <v-col cols="12"><div class="caption grey--text">Registered</div><div>{{ formatDate(selectedVehicle.created_at) }}</div></v-col>
          </v-row>
          <v-alert dense text type="info" class="mt-3 mb-0">
            This page is read-only. Vehicle approval and category changes will be enabled only after server-side permission checks and audit logging are verified.
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
  name: 'AdminVehicles',
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
      selectedVehicle: null,
      headers: [
        { text: 'Make', value: 'make' },
        { text: 'Model', value: 'model' },
        { text: 'Year', value: 'year' },
        { text: 'Plate', value: 'plate_number' },
        { text: 'Category', value: 'category_code' },
        { text: 'Owner', value: 'owner_name' },
        { text: 'Status', value: 'approval_status' },
        { text: 'Registered', value: 'created_at' },
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
        [item.make, item.model, item.year, item.plate_number, item.category_code, item.owner_name, item.owner_user_id, item.id]
          .some(value => String(value || '').toLowerCase().includes(term))
      )
    }
  },
  mounted() {
    this.loadItems()
  },
  methods: {
    formatDate(value) {
      return value ? new Date(value).toLocaleString() : '—'
    },
    statusColor(status) {
      if (status === 'approved') return 'success'
      if (status === 'pending') return 'warning'
      if (status === 'rejected' || status === 'suspended') return 'error'
      return 'grey'
    },
    openVehicle(vehicle) {
      this.selectedVehicle = vehicle
      this.detailsDialog = true
    },
    async loadItems() {
      this.loading = true
      this.errorMessage = ''
      try {
        if (!supabase) throw new Error('Supabase configuration is missing.')
        const from = (this.page - 1) * this.itemsPerPage
        const to = from + this.itemsPerPage - 1
        const { data: vehicles, count, error } = await supabase
          .from('vehicles')
          .select('*', { count: 'exact' })
          .order('created_at', { ascending: false })
          .range(from, to)
        if (error) throw error
        this.totalItems = count || 0

        const ownerIds = Array.from(new Set((vehicles || []).map(vehicle => vehicle.owner_user_id).filter(Boolean)))
        let ownersById = {}
        if (ownerIds.length) {
          const { data: owners, error: ownerError } = await supabase
            .from('profiles')
            .select('id, full_name, email')
            .in('id', ownerIds)
          if (ownerError) throw ownerError
          ownersById = (owners || []).reduce((result, owner) => {
            result[owner.id] = owner
            return result
          }, {})
        }
        this.items = (vehicles || []).map(vehicle => ({
          ...vehicle,
          owner_name: ownersById[vehicle.owner_user_id]
            ? (ownersById[vehicle.owner_user_id].full_name || ownersById[vehicle.owner_user_id].email || vehicle.owner_user_id)
            : (vehicle.owner_user_id || '—')
        }))
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load vehicles. Check the admin RLS policies for vehicles and profiles.'
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
