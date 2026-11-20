<template>
  <div class="driver-shell">
    <header><img src="/g-o-mark.svg" alt="MOONRIDE GO"><div><strong>MOONRIDE GO</strong><small>DRIVER</small></div><button @click="$router.push({name:'driver-profile'})">პროფილი</button></header>
    <main><router-view/></main>
    <nav><button :class="{active:$route.name==='driver-home'}" @click="go('driver-home')">მთავარი</button><button :class="{active:$route.name==='driver-orders'}" @click="go('driver-orders')">შეკვეთები</button><button :class="{active:$route.name==='driver-profile'}" @click="go('driver-profile')">პროფილი</button></nav>
  </div>
</template>
<script>
export default { name:'DriverShell', methods:{go(name){if(this.$route.name!==name)this.$router.push({name})}} }
</script>
<style scoped>
.driver-shell{min-height:100vh;background:#07152B;color:#F2F7FF;padding-bottom:76px}
header{height:66px;position:fixed;z-index:5;top:0;left:0;right:0;background:#061225;border-bottom:1px solid rgba(70,133,215,.18);display:flex;align-items:center;padding:0 14px;gap:10px}
header img{width:40px;height:40px;object-fit:contain}header strong{font-size:13px;letter-spacing:.5px}header small{display:block;color:#48B7FF;font-size:9px;letter-spacing:2px;margin-top:3px}
header button{margin-left:auto;color:#dfe7f5;font-size:12px;padding:9px}
main{padding:82px 16px 20px;max-width:760px;margin:auto}
nav{position:fixed;z-index:8;bottom:0;left:0;right:0;height:68px;display:flex;background:#070D1B;border-top:1px solid rgba(70,133,215,.2)}
nav button{flex:1;color:#8494ae;font-size:12px;font-weight:700}nav button.active{color:#48B7FF}
</style>