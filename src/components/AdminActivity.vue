<template>
  <v-container fluid class="admin-page">
    <h1 class="mb-4">Activity / Orders</h1>
    <v-alert type="info" text>
      The old Airtable activity feed has been disconnected. This screen will be connected to the verified MOONRIDE GO ride and order tables after the order schema and status fields are confirmed.
    </v-alert>
    <v-card dark color="#111c2b" outlined class="pa-4">
      <div class="title">Order activity</div>
      <div class="body-2 grey--text mt-2">No external data source is queried and no orders are modified on this screen.</div>
    </v-card>
  </v-container>
</template>
<script>
export default { name: 'AdminActivity' }
</script>
<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
</style>
