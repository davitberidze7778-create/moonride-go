<template>
  <v-container fluid class="admin-page">
    <h1 class="mb-4">Database tools</h1>
    <v-alert type="warning" text>
      Database maintenance actions are intentionally disabled in this first MASTER ADMIN release. Existing GO tables and records are preserved.
    </v-alert>
    <v-card dark color="#111c2b" outlined class="pa-4">
      <div class="title">Supabase database</div>
      <div class="body-2 grey--text mt-2">This page is read-only until each administrative operation has been reviewed and protected by server-side authorization.</div>
    </v-card>
  </v-container>
</template>
<script>
export default { name: 'AdminDBManagement' }
</script>
<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
</style>
