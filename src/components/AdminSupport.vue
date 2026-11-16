<template>
  <v-container fluid class="admin-page">
    <div class="overline amber--text text--accent-3">MASTER ADMIN / CUSTOMER CARE</div>
    <h1 class="mb-2">Support</h1>
    <p class="grey--text">MOONRIDE GO passenger and driver support workspace</p>

    <v-alert type="warning" text>
      The legacy OpenRide support page has been removed from this administration screen. A live support inbox cannot be connected yet because the audited Supabase schema does not currently contain a verified support-ticket table or message workflow.
    </v-alert>

    <v-card dark color="#111c2b" outlined class="pa-4">
      <div class="title mb-2">Support workspace</div>
      <div class="body-2 grey--text">
        The finished module will include passenger and driver requests, linked ride IDs, priority, assignment to support agents, replies, status history and an audit trail.
      </div>
      <v-divider class="my-4" />
      <div class="subtitle-2">Current status</div>
      <v-chip color="warning" text-color="white" small class="mt-2">Backend connection required</v-chip>
      <div class="caption grey--text mt-3">
        No support messages are being read, created or changed on this screen.
      </div>
    </v-card>
  </v-container>
</template>

<script>
export default {
  name: 'AdminSupport'
}
</script>

<style scoped>
.admin-page { min-height: 100vh; background: #080e18; color: #f4f6f8; }
</style>
