<template>
  <div class="moonride-logo">
    <img class="moonride-logo__mark" src="/moonride-go-mark.svg" alt="MOONRIDE GO emblem">
    <div class="moonride-logo__name"><span>MOONRIDE</span><strong>GO</strong></div>
    <div class="moonride-logo__caption">MASTER ADMIN</div>
  </div>
</template>

<script>
export default {
  name: 'MoonrideLogo'
}
</script>

<style scoped>
.moonride-logo {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  padding: 16px 8px 18px;
  text-align: center;
}
.moonride-logo__mark {
  width: 76px;
  height: 76px;
  object-fit: contain;
  filter: drop-shadow(0 8px 16px rgba(0, 0, 0, .28));
}
.moonride-logo__name {
  color: #f3f6ff;
  font-size: 19px;
  font-weight: 800;
  letter-spacing: .4px;
  line-height: 1.1;
}
.moonride-logo__name strong {
  color: #f5bd18;
  margin-left: 4px;
}
.moonride-logo__caption {
  color: #8494b1;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 2.2px;
}
</style>