<template>
  <v-container fluid class="admin-page">
    <h1 class="mb-4">Drivers</h1>
    <v-alert v-if="errorMessage" type="warning" dense>{{ errorMessage }}</v-alert>
    <v-card dark color="#111c2b" outlined>
      <v-card-title>
        Driver accounts
        <v-spacer></v-spacer>
        <v-btn small outlined color="amber" :loading="loading" @click="loadItems">Refresh</v-btn>
      </v-card-title>
      <v-data-table :headers="headers" :items="items" :loading="loading" :items-per-page="10" dark class="elevation-0">
        <template v-slot:item.created_at="{ item }">{{ item.created_at ? new Date(item.created_at).toLocaleString() : '—' }}</template>
        <template v-slot:no-data>No driver accounts found or access is restricted by database policies.</template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'
export default {
  data() {
    return {
      loading: false,
      errorMessage: '',
      items: [],
      headers: [
        { text: 'Name', value: 'full_name' },
        { text: 'Email', value: 'email' },
        { text: 'Phone', value: 'phone' },
        { text: 'Registered', value: 'created_at' },
        { text: 'User ID', value: 'id' }
      ]
    }
  },
  mounted() { this.loadItems() },
  methods: {
    async loadItems() {
      this.loading = true
      this.errorMessage = ''
      try {
        if (!supabase) throw new Error('Supabase configuration is missing.')
        const { data, error } = await supabase.from('profiles')
          .select('id, full_name, email, phone, created_at')
          .eq('role', 'driver')
          .order('created_at', { ascending: false })
        if (error) throw error
        this.items = data || []
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load driver accounts.'
      } finally {
        this.loading = false
      }
    }
  }
}
</script>

<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
</style>
