// src/plugins/vuetify.js

import Vue from 'vue'
import Vuetify from 'vuetify/lib'

Vue.use(Vuetify)

export default new Vuetify({
  theme: {
    dark: true,
    themes: {
      dark: {
        primary: '#2F80FF',
        secondary: '#48B7FF',
        accent: '#8BCBFF',
        background: '#07152B',
        surface: '#102544',
        info: '#48B7FF',
        success: '#29C995',
        warning: '#FFB547',
        error: '#FF647C'
      }
    }
  }
})