<template>
  <v-container fluid class="admin-page">
    <h1 class="mb-4">Finance</h1>
    <v-alert type="info" text>
      Finance tools are not connected yet. This page will be connected to MOONRIDE GO payment, commission, refund and payout records after their database structure is verified.
    </v-alert>
    <v-card dark color="#111c2b" outlined class="pa-4">
      <div class="title">Finance module</div>
      <div class="body-2 grey--text mt-2">No external Airtable embed is loaded. No financial data is changed here.</div>
    </v-card>
  </v-container>
</template>
<script>
export default { name: 'AdminBilling' }
</script>
<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
</style>
