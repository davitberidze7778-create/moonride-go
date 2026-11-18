<template>
  <v-app dark class="passenger-app">
    <transition name="splash-fade">
      <div v-if="showSplash" class="splash-screen" aria-label="MoonrideGo loading">
        <div class="splash-glow"></div>
        <img src="/g-o-mark.svg" class="splash-mark" alt="MoonrideGo emblem">
        <div class="splash-brand">Moonride<span>Go</span></div>
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
  position: fixed; inset: 0; z-index: 9999; display: flex; flex-direction: column;
  align-items: center; justify-content: center; overflow: hidden;
  background: radial-gradient(circle at 50% 42%, #173F74 0%, #0B1D3A 42%, #040B18 100%);
}
.splash-glow {
  position: absolute; width: min(92vw, 440px); height: min(92vw, 440px);
  border-radius: 50%; background: rgba(47,128,255,.27); filter: blur(86px);
}
.splash-mark {
  position: relative; display: block; width: min(82vw, 380px); height: auto;
  max-height: 52vh; object-fit: contain;
  filter: drop-shadow(0 0 32px rgba(47,128,255,.38)) drop-shadow(0 14px 34px rgba(0,0,0,.45));
}
.splash-brand {
  position: relative; margin-top: 14px; color: #F4F8FF; font-weight: 900;
  letter-spacing: .6px; font-size: 24px;
  text-shadow: 0 0 18px rgba(47,128,255,.28);
}
.splash-brand span { color: var(--mr-neon); margin-left: 2px; }
.splash-loading {
  position: relative; margin-top: 27px; color: #B8D9FF;
  font-size: 13px; letter-spacing: 1.5px;
}
.loading-dot {
  display: inline-block; width: 7px; height: 7px; border-radius: 50%;
  background: var(--mr-neon); margin-right: 9px;
  box-shadow: 0 0 12px rgba(72,183,255,.95); animation: pulse-dot 1.1s infinite;
}
.splash-progress {
  position: relative; width: 174px; height: 3px; margin-top: 17px;
  background: rgba(184,217,255,.18); overflow: hidden; border-radius: 9px;
}
.splash-progress span {
  display: block; height: 100%; width: 36%; background: var(--mr-blue);
  box-shadow: 0 0 12px rgba(72,183,255,.9); border-radius: 9px;
  animation: loading-line 5s linear forwards;
}
@keyframes pulse-dot { 50% { opacity: .25; transform: scale(.7); } }
@keyframes loading-line {
  0% { transform: translateX(-110%); }
  100% { transform: translateX(280%); }
}
.splash-fade-leave-active { transition: opacity .45s ease; }
.splash-fade-leave-to { opacity: 0; }
* { -webkit-tap-highlight-color: transparent; }
.v-application { font-family: Roboto, "Segoe UI", sans-serif !important; }
</style>
