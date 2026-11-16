<template>
  <v-container fluid class="admin-page">
    <v-row align="center" class="mb-3">
      <v-col cols="12" md="7">
        <div class="overline amber--text text--accent-3">MASTER ADMIN / OPERATIONS</div>
        <h1 class="mb-1">Drivers</h1>
        <div class="caption grey--text">Driver accounts joined with GO driver profiles, vehicles and document status</div>
      </v-col>
      <v-col cols="12" md="5" class="text-md-right">
        <v-chip color="#263548" text-color="white" class="mr-2">Total: {{ totalItems }}</v-chip>
        <v-btn small outlined color="amber" :loading="loading" @click="loadItems">Refresh</v-btn>
      </v-col>
    </v-row>

    <v-alert v-if="errorMessage" type="warning" dense>{{ errorMessage }}</v-alert>
    <v-card dark color="#111c2b" outlined>
      <v-card-title>
        Driver accounts
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
            {{ item.approval_status || 'profile missing' }}
          </v-chip>
        </template>
        <template v-slot:item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
        <template v-slot:item.actions="{ item }">
          <v-btn small text color="amber" @click="openProfile(item)">View profile</v-btn>
        </template>
        <template v-slot:no-data>No driver accounts found or access is restricted by database policies.</template>
        <template v-slot:no-results>No drivers on this page match the search.</template>
      </v-data-table>
      <div class="d-flex align-center justify-center pa-3" v-if="pageCount > 1">
        <v-pagination v-model="page" :length="pageCount" :total-visible="5" color="amber" @input="loadItems" />
      </div>
    </v-card>

    <v-dialog v-model="profileDialog" max-width="720">
      <v-card dark color="#111c2b" v-if="selectedDriver">
        <v-card-title>
          Driver profile
          <v-spacer></v-spacer>
          <v-btn icon @click="profileDialog = false"><v-icon>mdi-close</v-icon></v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row>
            <v-col cols="12" sm="6">
              <div class="caption grey--text">Full name</div>
              <div>{{ selectedDriver.full_name || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="caption grey--text">Approval status</div>
              <div>{{ selectedDriver.approval_status || 'Driver profile not found' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="caption grey--text">Email</div>
              <div>{{ selectedDriver.email || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="caption grey--text">Phone</div>
              <div>{{ selectedDriver.phone || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="caption grey--text">Residence city ID</div>
              <div class="user-id">{{ selectedDriver.driverProfile ? (selectedDriver.driverProfile.residence_city_id || '—') : '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="caption grey--text">Work city ID</div>
              <div class="user-id">{{ selectedDriver.driverProfile ? (selectedDriver.driverProfile.work_city_id || '—') : '—' }}</div>
            </v-col>
            <v-col cols="12">
              <div class="caption grey--text">Vehicles</div>
              <div v-for="vehicle in selectedDriver.vehicles" :key="vehicle.id" class="mb-2">
                {{ vehicle.make || '' }} {{ vehicle.model || '' }} {{ vehicle.year || '' }}
                <span v-if="vehicle.plate_number"> · {{ vehicle.plate_number }}</span>
                <span v-if="vehicle.approval_status"> · {{ vehicle.approval_status }}</span>
              </div>
              <div v-if="!selectedDriver.vehicles.length">No vehicle records found</div>
            </v-col>
            <v-col cols="12">
              <div class="caption grey--text">Documents</div>
              <div v-if="selectedDriver.documents.length">
                <v-chip v-for="(doc, index) in selectedDriver.documents" :key="index" x-small class="ma-1" :color="statusColor(doc.status)" text-color="white">
                  {{ doc.document_type || 'Document' }}: {{ doc.status || 'unknown' }}
                </v-chip>
              </div>
              <div v-else>No uploaded document records found</div>
            </v-col>
            <v-col cols="12">
              <div class="caption grey--text">Registration date</div>
              <div>{{ formatDate(selectedDriver.created_at) }}</div>
              <div class="caption grey--text mt-2">Account ID</div>
              <div class="user-id">{{ selectedDriver.id }}</div>
            </v-col>
          </v-row>
          <v-alert dense text type="info" class="mt-3 mb-0">
            This page is read-only. Approval, suspension and document decisions will be enabled only after their server-side permission checks and audit records are verified.
          </v-alert>
        </v-card-text>
        <v-card-actions><v-spacer /><v-btn text color="amber" @click="profileDialog = false">Close</v-btn></v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

export default {
  name: 'AdminAllDrivers',
  data() {
    return {
      loading: false,
      errorMessage: '',
      search: '',
      items: [],
      totalItems: 0,
      page: 1,
      itemsPerPage: 25,
      profileDialog: false,
      selectedDriver: null,
      headers: [
        { text: 'Driver', value: 'full_name' },
        { text: 'Email', value: 'email' },
        { text: 'Phone', value: 'phone' },
        { text: 'Approval', value: 'approval_status' },
        { text: 'Vehicle', value: 'vehicle_summary', sortable: false },
        { text: 'Documents', value: 'documents_summary', sortable: false },
        { text: 'Registered', value: 'created_at' },
        { text: 'Profile', value: 'actions', sortable: false }
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
        [item.full_name, item.email, item.phone, item.id, item.vehicle_summary]
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
    openProfile(item) {
      this.selectedDriver = item
      this.profileDialog = true
    },
    async loadItems() {
      this.loading = true
      this.errorMessage = ''
      try {
        if (!supabase) throw new Error('Supabase configuration is missing.')
        const from = (this.page - 1) * this.itemsPerPage
        const to = from + this.itemsPerPage - 1
        const { data: profiles, count, error: profileError } = await supabase
          .from('profiles')
          .select('id, full_name, email, phone, created_at', { count: 'exact' })
          .eq('role', 'driver')
          .order('created_at', { ascending: false })
          .range(from, to)
        if (profileError) throw profileError
        this.totalItems = count || 0

        const ids = (profiles || []).map(profile => profile.id)
        if (!ids.length) {
          this.items = []
          return
        }

        const [driverResult, vehicleResult, documentResult] = await Promise.all([
          supabase.from('driver_profiles').select('*').in('user_id', ids),
          supabase.from('vehicles').select('*').in('owner_user_id', ids),
          supabase.from('driver_documents').select('*').in('driver_user_id', ids)
        ])
        if (driverResult.error) throw driverResult.error
        if (vehicleResult.error) throw vehicleResult.error
        if (documentResult.error) throw documentResult.error

        const driverByUser = {}
        ;(driverResult.data || []).forEach(row => { driverByUser[row.user_id] = row })
        const vehiclesByUser = {}
        ;(vehicleResult.data || []).forEach(row => {
          if (!vehiclesByUser[row.owner_user_id]) vehiclesByUser[row.owner_user_id] = []
          vehiclesByUser[row.owner_user_id].push(row)
        })
        const documentsByUser = {}
        ;(documentResult.data || []).forEach(row => {
          if (!documentsByUser[row.driver_user_id]) documentsByUser[row.driver_user_id] = []
          documentsByUser[row.driver_user_id].push(row)
        })

        this.items = (profiles || []).map(profile => {
          const driverProfile = driverByUser[profile.id] || null
          const vehicles = vehiclesByUser[profile.id] || []
          const documents = documentsByUser[profile.id] || []
          const legalName = driverProfile
            ? [driverProfile.legal_first_name, driverProfile.legal_last_name].filter(Boolean).join(' ')
            : ''
          const vehicleSummary = vehicles.length
            ? vehicles.map(vehicle => [vehicle.make, vehicle.model, vehicle.year].filter(Boolean).join(' ') + (vehicle.plate_number ? ' · ' + vehicle.plate_number : '')).join('; ')
            : '—'
          const documentSummary = documents.length
            ? documents.length + ' file(s): ' + documents.map(document => document.status || 'unknown').join(', ')
            : 'No documents'
          return {
            ...profile,
            full_name: legalName || profile.full_name || '—',
            approval_status: driverProfile ? driverProfile.approval_status : null,
            driverProfile,
            vehicles,
            documents,
            vehicle_summary: vehicleSummary,
            documents_summary: documentSummary
          }
        })
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load driver details. Check the admin RLS policies for driver profiles, vehicles and documents.'
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
