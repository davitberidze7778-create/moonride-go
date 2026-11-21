<template>
  <v-app dark class="passenger-app">
    <transition name="splash-fade">
      <div v-if="showSplash" class="splash-screen" aria-label="MoonrideGo loading">
        <div class="splash-glow"></div>
        <img src="/g-o-mark.svg" class="splash-mark" alt="MoonrideGo M location logo">
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
    // Keep the agreed five-second branded startup, then let the router
    // send signed-in passengers to Home or new users to authentication.
    this.splashTimer = window.setTimeout(() => { this.showSplash = false }, 5000)
  },
  beforeDestroy() {
    if (this.splashTimer) window.clearTimeout(this.splashTimer)
  }
}
</script>

<style>
:root {
  color-scheme: dark;
  --mr-bg: #07152B;
  --mr-panel: #102544;
  --mr-panel-2: #17365C;
  --mr-blue: #2F80FF;
  --mr-neon: #48B7FF;
  --mr-silver: #F2F7FF;
  --mr-muted: #A8C6E8;
}
html, body, #app {
  min-height: 100%; width: 100%; margin: 0; background: var(--mr-bg);
}
body { overflow-x: hidden; }
.passenger-app, .passenger-root {
  min-height: 100vh; background: var(--mr-bg) !important; color: var(--mr-silver);
}
.splash-screen {
  position: fixed; inset: 0; z-index: 9999; display: flex;
  align-items: center; justify-content: center; overflow: hidden;
  background: radial-gradient(circle at 50% 46%, #173F74 0%, #0B1D3A 43%, #040B18 100%);
}
.splash-glow {
  position: absolute; width: min(96vw, 470px); height: min(96vw, 470px);
  border-radius: 50%; background: rgba(47,128,255,.27); filter: blur(88px);
}
.splash-mark {
  position: relative; display: block; width: min(82vw, 390px);
  height: auto; max-height: 62vh; object-fit: contain;
  filter: drop-shadow(0 0 32px rgba(47,128,255,.38)) drop-shadow(0 14px 34px rgba(0,0,0,.45));
  animation: moonride-logo-enter 1.15s cubic-bezier(.16,.78,.25,1) both;
}
@keyframes moonride-logo-enter {
  0% { opacity: 0; transform: scale(.76); }
  72% { opacity: 1; transform: scale(1.035); }
  100% { opacity: 1; transform: scale(1); }
}
.splash-fade-leave-active { transition: opacity .42s ease; }
.splash-fade-leave-to { opacity: 0; }
* { -webkit-tap-highlight-color: transparent; }
.v-application { font-family: Roboto, "Segoe UI", sans-serif !important; }
</style>
