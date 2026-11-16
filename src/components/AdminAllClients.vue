<template>
  <v-container fluid class="admin-page">
    <v-row align="center" class="mb-3">
      <v-col cols="12" md="7">
        <div class="overline amber--text text--accent-3">MASTER ADMIN / ACCOUNTS</div>
        <h1 class="mb-1">Passengers</h1>
        <div class="caption grey--text">Passenger accounts from the existing GO database</div>
      </v-col>
      <v-col cols="12" md="5" class="text-md-right">
        <v-chip color="#263548" text-color="white" class="mr-2">Total: {{ totalItems }}</v-chip>
        <v-btn small outlined color="amber" :loading="loading" @click="loadItems">Refresh</v-btn>
      </v-col>
    </v-row>

    <v-alert v-if="errorMessage" type="warning" dense>{{ errorMessage }}</v-alert>

    <v-card dark color="#111c2b" outlined>
      <v-card-title>
        Passenger accounts
        <v-spacer></v-spacer>
        <v-text-field
          v-model="search"
          append-icon="mdi-magnify"
          label="Search name, email, phone or exact ID"
          single-line
          hide-details
          clearable
          dense
          outlined
          style="max-width: 360px"
          @keyup.enter="applySearch"
        />
        <v-btn small color="amber darken-2" class="ml-2" :loading="loading" @click="applySearch">Search</v-btn>
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="items"
        :loading="loading"
        :items-per-page="itemsPerPage"
        :hide-default-footer="true"
        dark
        class="elevation-0"
      >
        <template v-slot:item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
        <template v-slot:item.actions="{ item }">
          <v-btn small text color="amber" @click="openProfile(item)">View profile</v-btn>
        </template>
        <template v-slot:no-data>No passenger accounts found or access is restricted by database policies.</template>
      </v-data-table>
      <div class="d-flex align-center justify-center pa-3" v-if="pageCount > 1">
        <v-pagination v-model="page" :length="pageCount" :total-visible="5" color="amber" @input="loadItems" />
      </div>
    </v-card>

    <v-dialog v-model="profileDialog" max-width="620">
      <v-card dark color="#111c2b" v-if="selectedPassenger">
        <v-card-title>
          Passenger profile
          <v-spacer></v-spacer>
          <v-btn icon @click="profileDialog = false"><v-icon>mdi-close</v-icon></v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-list dark color="transparent">
            <v-list-item>
              <v-list-item-content><v-list-item-subtitle>Full name</v-list-item-subtitle><v-list-item-title>{{ selectedPassenger.full_name || '—' }}</v-list-item-title></v-list-item-content>
            </v-list-item>
            <v-list-item>
              <v-list-item-content><v-list-item-subtitle>Email</v-list-item-subtitle><v-list-item-title>{{ selectedPassenger.email || '—' }}</v-list-item-title></v-list-item-content>
            </v-list-item>
            <v-list-item>
              <v-list-item-content><v-list-item-subtitle>Phone</v-list-item-subtitle><v-list-item-title>{{ selectedPassenger.phone || '—' }}</v-list-item-title></v-list-item-content>
            </v-list-item>
            <v-list-item>
              <v-list-item-content><v-list-item-subtitle>Registration date</v-list-item-subtitle><v-list-item-title>{{ formatDate(selectedPassenger.created_at) }}</v-list-item-title></v-list-item-content>
            </v-list-item>
            <v-list-item>
              <v-list-item-content><v-list-item-subtitle>Account ID</v-list-item-subtitle><v-list-item-title class="text-caption user-id">{{ selectedPassenger.id }}</v-list-item-title></v-list-item-content>
            </v-list-item>
          </v-list>
          <v-alert dense text type="info" class="mt-2 mb-0">
            This view is read-only. Account status and suspension controls will be added only after the corresponding database fields and access rules are verified.
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
  name: 'AdminAllClients',
  data() {
    return {
      loading: false,
      errorMessage: '',
      search: '',
      appliedSearch: '',
      items: [],
      totalItems: 0,
      page: 1,
      itemsPerPage: 25,
      profileDialog: false,
      selectedPassenger: null,
      headers: [
        { text: 'Name', value: 'full_name' },
        { text: 'Email', value: 'email' },
        { text: 'Phone', value: 'phone' },
        { text: 'Registered', value: 'created_at' },
        { text: 'Profile', value: 'actions', sortable: false }
      ]
    }
  },
  computed: {
    pageCount() {
      return Math.max(1, Math.ceil(this.totalItems / this.itemsPerPage))
    }
  },
  mounted() {
    this.loadItems()
  },
  methods: {
    formatDate(value) {
      return value ? new Date(value).toLocaleString() : '—'
    },
    openProfile(item) {
      this.selectedPassenger = item
      this.profileDialog = true
    },
    applySearch() {
      this.appliedSearch = (this.search || '').trim()
      this.page = 1
      this.loadItems()
    },
    async loadItems() {
      this.loading = true
      this.errorMessage = ''
      try {
        if (!supabase) throw new Error('Supabase configuration is missing.')
        const from = (this.page - 1) * this.itemsPerPage
        const to = from + this.itemsPerPage - 1
        let query = supabase.from('profiles')
          .select('id, full_name, email, phone, created_at', { count: 'exact' })
          .eq('role', 'passenger')

        const term = this.appliedSearch
        if (term && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(term)) {
          query = query.eq('id', term)
        } else if (term) {
          const safeTerm = term.replace(/[\\]/g, '\\\\').replace(/"/g, '\\"').slice(0, 100)
          const pattern = '"*' + safeTerm + '*"'
          query = query.or('full_name.ilike.' + pattern + ',email.ilike.' + pattern + ',phone.ilike.' + pattern)
        }

        const { data, count, error } = await query
          .order('created_at', { ascending: false })
          .range(from, to)
        if (error) throw error
        this.items = data || []
        this.totalItems = count || 0
        if (this.page > this.pageCount) {
          this.page = this.pageCount
          return this.loadItems()
        }
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load passenger accounts.'
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
