<template>
  <section class="page">
    <div class="eyebrow">MOONRIDE GO · DRIVER</div><h1>მძღოლის მთავარი გვერდი</h1>
    <v-card class="status-card" elevation="0">
      <div class="status-title"><v-icon color="#48B7FF">mdi-shield-check</v-icon> ანგარიში ავტორიზებულია</div>
      <p>მძღოლის ანგარიში წარმატებით არის დაკავშირებული MOONRIDE GO-სთან.</p>
      <div class="status-note">შეკვეთების მიღება, ონლაინ სტატუსი და GPS ტრეკინგი ჩაირთვება მხოლოდ შესაბამისი Supabase ფუნქციებისა და უსაფრთხოების წესების შემოწმების შემდეგ.</div>
    </v-card>
    <v-card class="info-card" elevation="0"><h2>შემდეგი ეტაპი</h2><p>ამ ვერსიაში ხელმისაწვდომია მძღოლის ავტორიზაცია და ანგარიშის დაცული შემოწმება. რეალური შეკვეთების მიღებას არ ვაჩვენებთ, სანამ backend-ის კავშირი არ დადასტურდება.</p></v-card>
  </section>
</template>
<script>
export default {name:'DriverHome'}
</script>
<style scoped>
.page{color:#F2F7FF}.eyebrow{font-size:9px;letter-spacing:2px;color:#48B7FF;font-weight:800}h1{font-size:23px;margin:8px 0 18px;font-weight:900}
.status-card,.info-card{background:#102544!important;border:1px solid rgba(82,145,225,.18)!important;border-radius:16px!important;padding:18px;color:#E3E9F5;margin-bottom:14px}
.status-title{font-size:15px;font-weight:800;display:flex;align-items:center;gap:9px}.status-card p,.info-card p{font-size:12px;line-height:1.65;color:#A8B8D0;margin:12px 0}
.status-note{font-size:11px;line-height:1.6;color:#91A8C7;border-top:1px solid rgba(82,145,225,.18);padding-top:12px}
.info-card h2{font-size:14px;margin:0}
</style>