<template>
  <v-app dark class="passenger-app">
    <transition name="splash-fade">
      <div v-if="showSplash" class="splash-screen">
        <div class="splash-glow"></div>
        <img src="/g-o-mark.svg" class="splash-mark" alt="G_o">
        <div class="splash-brand">G_<span>o</span></div>
        <div class="splash-loading"><span class="loading-dot"></span> Loading...</div>
        <div class="splash-progress"><span></span></div>
      </div>
    </transition>
    <div v-if="!showSplash" class="passenger-root">
      <router-view />
    </div>
  </v-app>
</template>

<script>
export default {
  name: 'App',
  data() {
    return { showSplash: true, splashTimer: null }
  },
  mounted() {
    // Keep the branded startup screen visible for the agreed 10 seconds.
    this.splashTimer = window.setTimeout(() => {
      this.showSplash = false
    }, 10000)
  },
  beforeDestroy() {
    if (this.splashTimer) window.clearTimeout(this.splashTimer)
  }
}
</script>

<style>
:root {
  color-scheme: dark;
  --mr-bg: #080e1c;
  --mr-panel: #111b2e;
  --mr-panel-2: #16233a;
  --mr-gold: #f5bd18;
  --mr-silver: #e3e9f5;
  --mr-muted: #8796b1;
}
html, body, #app {
  min-height: 100%;
  width: 100%;
  margin: 0;
  background: var(--mr-bg);
}
body { overflow-x: hidden; }
.passenger-app, .passenger-root { min-height: 100vh; background: var(--mr-bg) !important; color: var(--mr-silver); }
.splash-screen {
  position: fixed; inset: 0; z-index: 9999; display: flex; flex-direction: column;
  align-items: center; justify-content: center; overflow: hidden;
  background: radial-gradient(circle at 50% 42%, #18294b 0%, #0b1428 38%, #050914 100%);
}
.splash-glow {
  position: absolute; width: 300px; height: 300px; border-radius: 50%;
  background: rgba(245,189,24,.12); filter: blur(70px);
}
.splash-mark { position: relative; width: 132px; height: 132px; object-fit: contain; filter: drop-shadow(0 12px 28px rgba(0,0,0,.45)); }
.splash-brand { position: relative; margin-top: 20px; color: #f3f6ff; font-weight: 900; letter-spacing: 2px; font-size: 25px; }
.splash-brand span { color: var(--mr-gold); margin-left: 5px; }
.splash-loading { position: relative; margin-top: 42px; color: #aab6cc; font-size: 13px; letter-spacing: 1.4px; }
.loading-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: var(--mr-gold); margin-right: 9px; animation: pulse-dot 1.1s infinite; }
.splash-progress { position: relative; width: 150px; height: 3px; margin-top: 17px; background: rgba(255,255,255,.12); overflow: hidden; border-radius: 9px; }
.splash-progress span { display: block; height: 100%; width: 35%; background: var(--mr-gold); border-radius: 9px; animation: loading-line 2.2s ease-in-out infinite; }
@keyframes pulse-dot { 50% { opacity: .25; transform: scale(.7); } }
@keyframes loading-line { 0% { transform: translateX(-110%); } 100% { transform: translateX(430%); } }
.splash-fade-leave-active { transition: opacity .45s ease; }
.splash-fade-leave-to { opacity: 0; }
* { -webkit-tap-highlight-color: transparent; }
.v-application { font-family: Roboto, "Segoe UI", sans-serif !important; }
</style>
