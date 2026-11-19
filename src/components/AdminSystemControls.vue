<template>
  <v-container fluid class="controls-page pa-4 pa-md-6">
    <div class="page-head">
      <div>
        <div class="eyebrow">MOONRIDE GO / MASTER ADMIN</div>
        <h1>System Controls & Pricing</h1>
        <p>Manage GO categories, regional tariffs, dynamic pricing and passenger features</p>
      </div>
      <v-btn outlined color="blue lighten-2" :loading="loading" @click="loadAll">
        <v-icon left small>mdi-refresh</v-icon> Refresh
      </v-btn>
    </div>

    <v-alert v-if="errorMessage" type="error" dense text>{{ errorMessage }}</v-alert>
    <v-alert v-if="successMessage" type="success" dense text>{{ successMessage }}</v-alert>
    <v-alert type="info" dense text class="mb-4">
      Changes are saved to Supabase. Features marked “Backend not ready” cannot be enabled until their server-side workflow and security tests are complete.
    </v-alert>

    <v-card dark outlined class="control-card mb-5">
      <v-card-title class="section-title">
        <v-icon left color="amber">mdi-map-marker-radius</v-icon>
        Tariff scope
      </v-card-title>
      <v-card-text>
        <v-row align="center">
          <v-col cols="12" md="5">
            <v-select
              v-model="selectedCityId"
              :items="cities"
              item-text="name"
              item-value="id"
              label="City"
              outlined dense hide-details
              :disabled="loading || cities.length === 0"
              @change="loadPlan"
            />
          </v-col>
          <v-col cols="12" md="7">
            <div v-if="plan" class="plan-meta">
              <v-chip small color="blue darken-2" text-color="white">{{ plan.plan_name }}</v-chip>
              <v-chip small outlined color="green">{{ plan.currency_code }}</v-chip>
              <span>Version {{ plan.rule_version }}</span>
              <span>Min fare: {{ Number(plan.minimum_fare).toFixed(2) }} {{ plan.currency_code }}</span>
            </div>
            <div v-else class="caption grey--text">No active GO city tariff plan selected.</div>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <v-card dark outlined class="control-card mb-5">
      <v-card-title class="section-title">
        <v-icon left color="amber">mdi-car-multiple</v-icon>
        Seven approved ride categories
      </v-card-title>
      <v-card-subtitle>Enable or disable categories and update their per-kilometre rates for the selected GO plan.</v-card-subtitle>
      <v-card-text>
        <v-progress-linear v-if="categoriesLoading" indeterminate color="blue" />
        <div v-for="category in categories" :key="category.id" class="category-row">
          <div class="category-name">
            <strong>{{ category.label }}</strong>
            <small>{{ category.code }}</small>
          </div>
          <v-switch
            v-model="category.is_active"
            inset dense hide-details
            color="green"
            :label="category.is_active ? 'Enabled' : 'Disabled'"
            :disabled="category.saving"
            @change="saveCategoryState(category)"
          />
          <div class="rate-edit">
            <v-text-field
              v-model="category.rateDraft"
              type="number"
              min="0.01"
              step="0.01"
              suffix=" / km"
              dense outlined hide-details
              :disabled="!plan || category.rateSaving"
            />
            <v-btn small color="blue darken-2" :loading="category.rateSaving" :disabled="!plan || !validRate(category.rateDraft)" @click="saveRate(category)">
              Save rate
            </v-btn>
          </div>
        </div>
        <v-alert v-if="!categories.length && !categoriesLoading" dense text type="warning">
          Category rows are not available for this plan. Check its GO tariff category-rate rows.
        </v-alert>
      </v-card-text>
    </v-card>

    <v-card dark outlined class="control-card mb-5" v-if="plan">
      <v-card-title class="section-title">
        <v-icon left color="amber">mdi-weather-partly-rainy</v-icon>
        Dynamic, weather and demand pricing
      </v-card-title>
      <v-card-subtitle>Multiplier changes affect new quotes only. Existing quote snapshots remain unchanged.</v-card-subtitle>
      <v-card-text>
        <v-row>
          <v-col cols="12" md="4">
            <v-switch v-model="dynamic.is_active" inset color="green" label="Dynamic pricing active" />
            <v-switch v-model="dynamic.weather_enabled" inset color="blue" label="Weather multiplier" />
            <v-switch v-model="dynamic.demand_enabled" inset color="blue" label="Demand multiplier" />
          </v-col>
          <v-col cols="12" md="4">
            <v-text-field v-model="dynamic.weather_multiplier" type="number" min="1" step="0.01" label="Weather multiplier" suffix="×" outlined dense />
            <v-text-field v-model="dynamic.demand_multiplier" type="number" min="1" step="0.01" label="Demand multiplier" suffix="×" outlined dense />
            <v-text-field v-model="dynamic.max_multiplier" type="number" min="1" step="0.01" label="Maximum multiplier" suffix="×" outlined dense />
          </v-col>
          <v-col cols="12" md="4">
            <v-text-field v-model="dynamic.manual_override_multiplier" type="number" min="1" step="0.01" label="Manual override multiplier" suffix="×" outlined dense />
            <v-text-field v-model="dynamic.manual_override_until" type="datetime-local" label="Manual override expires" outlined dense />
            <div class="caption grey--text">Manual override takes precedence while valid and within the maximum multiplier.</div>
          </v-col>
        </v-row>
        <v-btn color="blue darken-2" :loading="dynamicSaving" :disabled="!validDynamic" @click="saveDynamic">
          <v-icon left>mdi-content-save</v-icon> Save pricing rules
        </v-btn>
      </v-card-text>
    </v-card>

    <v-card dark outlined class="control-card mb-5">
      <v-card-title class="section-title">
        <v-icon left color="amber">mdi-toggle-switch</v-icon>
        Passenger app feature switches
      </v-card-title>
      <v-card-subtitle>Available features can be switched off immediately. Pending features stay locked until their backend is implemented and tested.</v-card-subtitle>
      <v-card-text>
        <v-expansion-panels dark multiple accordion>
          <v-expansion-panel v-for="group in featureGroups" :key="group.key">
            <v-expansion-panel-header>
              <div class="group-heading">
                <strong>{{ group.label }}</strong>
                <v-chip x-small outlined>{{ group.items.length }} features</v-chip>
              </div>
            </v-expansion-panel-header>
            <v-expansion-panel-content>
              <div v-for="feature in group.items" :key="feature.feature_key" class="feature-row">
                <div class="feature-copy">
                  <strong>{{ feature.label }}</strong>
                  <small>{{ feature.description }}</small>
                  <span v-if="!feature.is_available" class="pending-note">Backend not ready — activation locked</span>
                </div>
                <v-switch
                  :input-value="feature.is_enabled"
                  inset dense hide-details color="green"
                  :disabled="!feature.is_available || feature.saving"
                  :loading="feature.saving"
                  @change="toggleFeature(feature, $event)"
                />
              </div>
            </v-expansion-panel-content>
          </v-expansion-panel>
        </v-expansion-panels>
      </v-card-text>
    </v-card>

    <v-card dark outlined class="control-card mb-5">
      <v-card-title class="section-title">
        <v-icon left color="amber">mdi-history</v-icon>
        Recent feature-change audit
      </v-card-title>
      <v-card-text>
        <v-data-table
          :headers="auditHeaders"
          :items="auditRows"
          :loading="auditLoading"
          dense dark
          :items-per-page="8"
          class="elevation-0"
        >
          <template v-slot:item.changed_at="{ item }">{{ formatDate(item.changed_at) }}</template>
          <template v-slot:item.old_state="{ item }">{{ stateText(item.old_state) }}</template>
          <template v-slot:item.new_state="{ item }">{{ stateText(item.new_state) }}</template>
          <template v-slot:no-data>No feature changes recorded yet.</template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <v-card dark outlined class="control-card">
      <v-card-title class="section-title">
        <v-icon left color="amber">mdi-cash-clock</v-icon>
        Recent tariff-change audit
      </v-card-title>
      <v-card-text>
        <v-data-table
          :headers="tariffAuditHeaders"
          :items="tariffAuditRows"
          :loading="tariffAuditLoading"
          dense dark
          :items-per-page="8"
          class="elevation-0"
        >
          <template v-slot:item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
          <template v-slot:item.reason="{ item }">{{ item.reason || '—' }}</template>
          <template v-slot:no-data>No tariff changes recorded yet.</template>
        </v-data-table>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script>
import supabase from '@/services/supabase'

const CATEGORY_ORDER = [
  ['ECONOM_GO', 'ECONOM'],
  ['ECONOM_PLUS_GO', 'ECONOM+'],
  ['COMFORT_GO', 'COMFORT'],
  ['COMFORT_PLUS_GO', 'COMFORT+'],
  ['XL_GO', 'XL'],
  ['MINIVAN_GO', 'MINIVAN'],
  ['GROUP_RIDE_GO', 'GROUP RIDE']
]

const GROUP_LABELS = {
  rides: 'Rides & booking',
  pricing: 'Pricing controls',
  safety: 'Safety',
  payments: 'Payments',
  promotions: 'Promotions & loyalty',
  add_ons: 'Ride add-ons',
  support: 'Support & AI'
}

export default {
  name: 'AdminSystemControls',
  data() {
    return {
      loading: false,
      categoriesLoading: false,
      dynamicSaving: false,
      auditLoading: false,
      tariffAuditLoading: false,
      errorMessage: '',
      successMessage: '',
      cities: [],
      selectedCityId: '',
      plan: null,
      categories: [],
      dynamic: this.emptyDynamic(),
      features: [],
      auditRows: [],
      tariffAuditRows: [],
      auditHeaders: [
        { text: 'Feature', value: 'feature_key' },
        { text: 'Previous', value: 'old_state' },
        { text: 'Current', value: 'new_state' },
        { text: 'Changed', value: 'changed_at' }
      ],
      tariffAuditHeaders: [
        { text: 'Action', value: 'action_type' },
        { text: 'Reason', value: 'reason' },
        { text: 'Changed', value: 'created_at' }
      ]
    }
  },
  computed: {
    featureGroups() {
      const grouped = {}
      this.features.forEach(feature => {
        const key = feature.feature_group || 'other'
        if (!grouped[key]) grouped[key] = []
        grouped[key].push(feature)
      })
      return Object.keys(grouped).sort().map(key => ({
        key,
        label: GROUP_LABELS[key] || key,
        items: grouped[key]
      }))
    },
    validDynamic() {
      const values = [
        this.dynamic.weather_multiplier,
        this.dynamic.demand_multiplier,
        this.dynamic.max_multiplier
      ].filter(value => value !== null && value !== '')
      return values.every(value => Number.isFinite(Number(value)) && Number(value) >= 1) &&
        (this.dynamic.manual_override_multiplier === null ||
         this.dynamic.manual_override_multiplier === '' ||
         (Number.isFinite(Number(this.dynamic.manual_override_multiplier)) && Number(this.dynamic.manual_override_multiplier) >= 1))
    }
  },
  async mounted() {
    await this.loadAll()
  },
  methods: {
    emptyDynamic() {
      return {
        id: null,
        tariff_plan_id: null,
        is_active: false,
        weather_enabled: false,
        demand_enabled: false,
        weather_multiplier: 1,
        demand_multiplier: 1,
        max_multiplier: null,
        manual_override_multiplier: null,
        manual_override_until: ''
      }
    },
    async loadAll() {
      if (!supabase) {
        this.errorMessage = 'Supabase configuration is missing.'
        return
      }
      this.loading = true
      this.errorMessage = ''
      this.successMessage = ''
      try {
        const [cityResult, featureResult] = await Promise.all([
          supabase.from('cities').select('id,name,is_active,service_enabled').eq('is_active', true).order('name'),
          supabase.from('go_app_feature_flags').select('*').order('feature_group').order('label')
        ])
        if (cityResult.error) throw cityResult.error
        if (featureResult.error) throw featureResult.error
        this.cities = cityResult.data || []
        this.features = featureResult.data || []
        if (!this.selectedCityId && this.cities.length) {
          const batumi = this.cities.find(city => city.name.toLowerCase() === 'batumi')
          this.selectedCityId = (batumi || this.cities[0]).id
        }
        if (this.selectedCityId) await this.loadPlan()
        await this.loadAudit()
      } catch (error) {
        this.errorMessage = error.message || 'Failed to load Master Admin settings.'
      } finally {
        this.loading = false
      }
    },
    async loadPlan() {
      if (!this.selectedCityId) return
      this.categoriesLoading = true
      this.plan = null
      this.categories = []
      try {
        const { data: plans, error } = await supabase
          .from('go_tariff_plans')
          .select('*')
          .eq('city_id', this.selectedCityId)
          .eq('scope_type', 'city')
          .eq('is_active', true)
          .order('effective_from', { ascending: false })
          .limit(5)
        if (error) throw error
        const now = Date.now()
        this.plan = (plans || []).find(item =>
          new Date(item.effective_from).getTime() <= now &&
          (!item.effective_until || new Date(item.effective_until).getTime() > now)
        ) || null
        if (!this.plan) {
          this.dynamic = this.emptyDynamic()
          return
        }
        const { data: rates, error: ratesError } = await supabase
          .from('go_tariff_category_rates')
          .select('id,category_id,rate_per_km')
          .eq('tariff_plan_id', this.plan.id)
        if (ratesError) throw ratesError
        const categoryIds = (rates || []).map(item => item.category_id)
        const { data: allCategories, error: categoryError } = await supabase
          .from('vehicle_categories')
          .select('id,code,name,is_active')
          .in('id', categoryIds.length ? categoryIds : ['00000000-0000-0000-0000-000000000000'])
        if (categoryError) throw categoryError
        const byCode = {}
        ;(allCategories || []).forEach(item => { byCode[item.code] = item })
        const rateByCategory = {}
        ;(rates || []).forEach(item => { rateByCategory[item.category_id] = item })
        this.categories = CATEGORY_ORDER.map(([code, label]) => {
          const category = byCode[code]
          if (!category) return null
          const rate = rateByCategory[category.id]
          return {
            id: category.id,
            code,
            label,
            is_active: category.is_active,
            rateId: rate ? rate.id : null,
            rateDraft: rate ? String(rate.rate_per_km) : '',
            rateSaving: false,
            saving: false
          }
        }).filter(Boolean)
        await this.loadDynamic()
      } catch (error) {
        this.errorMessage = error.message || 'Unable to load GO tariff plan.'
      } finally {
        this.categoriesLoading = false
      }
    },
    async loadDynamic() {
      if (!this.plan) return
      const { data, error } = await supabase
        .from('go_tariff_dynamic_rules')
        .select('*')
        .eq('tariff_plan_id', this.plan.id)
        .maybeSingle()
      if (error) throw error
      if (!data) {
        this.dynamic = { ...this.emptyDynamic(), tariff_plan_id: this.plan.id }
        return
      }
      this.dynamic = {
        ...data,
        weather_multiplier: String(data.weather_multiplier),
        demand_multiplier: String(data.demand_multiplier),
        max_multiplier: data.max_multiplier === null ? null : String(data.max_multiplier),
        manual_override_multiplier: data.manual_override_multiplier === null ? null : String(data.manual_override_multiplier),
        manual_override_until: data.manual_override_until
          ? new Date(new Date(data.manual_override_until).getTime() - new Date(data.manual_override_until).getTimezoneOffset() * 60000).toISOString().slice(0, 16)
          : ''
      }
    },
    async saveCategoryState(category) {
      category.saving = true
      this.errorMessage = ''
      try {
        const { error } = await supabase.from('vehicle_categories')
          .update({ is_active: category.is_active })
          .eq('id', category.id)
        if (error) throw error
        this.successMessage = category.label + (category.is_active ? ' enabled.' : ' disabled.')
        await this.loadPlan()
        await this.loadAudit()
      } catch (error) {
        category.is_active = !category.is_active
        this.errorMessage = error.message || 'Could not change category state.'
      } finally {
        category.saving = false
      }
    },
    validRate(value) {
      return Number.isFinite(Number(value)) && Number(value) > 0 && Number(value) <= 100000
    },
    async saveRate(category) {
      if (!category.rateId || !this.validRate(category.rateDraft)) return
      category.rateSaving = true
      this.errorMessage = ''
      try {
        const { error } = await supabase.from('go_tariff_category_rates')
          .update({ rate_per_km: Number(category.rateDraft) })
          .eq('id', category.rateId)
        if (error) throw error
        this.successMessage = category.label + ' rate updated.'
        await this.loadPlan()
        await this.loadAudit()
      } catch (error) {
        this.errorMessage = error.message || 'Could not update category rate.'
      } finally {
        category.rateSaving = false
      }
    },
    async saveDynamic() {
      if (!this.plan || !this.validDynamic) return
      this.dynamicSaving = true
      this.errorMessage = ''
      try {
        const payload = {
          tariff_plan_id: this.plan.id,
          is_active: this.dynamic.is_active,
          weather_enabled: this.dynamic.weather_enabled,
          demand_enabled: this.dynamic.demand_enabled,
          weather_multiplier: Number(this.dynamic.weather_multiplier || 1),
          demand_multiplier: Number(this.dynamic.demand_multiplier || 1),
          max_multiplier: this.dynamic.max_multiplier === null || this.dynamic.max_multiplier === '' ? null : Number(this.dynamic.max_multiplier),
          manual_override_multiplier: this.dynamic.manual_override_multiplier === null || this.dynamic.manual_override_multiplier === '' ? null : Number(this.dynamic.manual_override_multiplier),
          manual_override_until: this.dynamic.manual_override_until ? new Date(this.dynamic.manual_override_until).toISOString() : null,
          updated_at: new Date().toISOString()
        }
        const { error } = await supabase.from('go_tariff_dynamic_rules')
          .upsert(payload, { onConflict: 'tariff_plan_id' })
        if (error) throw error
        this.successMessage = 'Dynamic pricing rules saved.'
        await this.loadPlan()
        await this.loadAudit()
      } catch (error) {
        this.errorMessage = error.message || 'Could not save dynamic pricing.'
      } finally {
        this.dynamicSaving = false
      }
    },
    async toggleFeature(feature, nextValue) {
      const previous = feature.is_enabled
      this.$set(feature, 'saving', true)
      this.errorMessage = ''
      try {
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) throw new Error('Admin session expired.')
        const { error } = await supabase.from('go_app_feature_flags')
          .update({ is_enabled: nextValue, updated_by: user.id, updated_at: new Date().toISOString() })
          .eq('feature_key', feature.feature_key)
        if (error) throw error
        feature.is_enabled = nextValue
        this.successMessage = feature.label + (nextValue ? ' enabled.' : ' disabled.')
        await this.loadAudit()
      } catch (error) {
        feature.is_enabled = previous
        this.errorMessage = error.message || 'Could not change feature state.'
      } finally {
        this.$set(feature, 'saving', false)
      }
    },
    async loadAudit() {
      this.auditLoading = true
      this.tariffAuditLoading = true
      try {
        const [features, tariffs] = await Promise.all([
          supabase.from('go_app_feature_flag_audit')
            .select('id,feature_key,old_state,new_state,changed_at')
            .order('changed_at', { ascending: false }).limit(30),
          supabase.from('go_tariff_audit_log')
            .select('id,action_type,old_values,new_values,reason,created_at')
            .order('created_at', { ascending: false }).limit(30)
        ])
        if (features.error) throw features.error
        this.auditRows = features.data || []
        this.tariffAuditRows = tariffs.error ? [] : (tariffs.data || [])
      } catch (error) {
        this.auditRows = []
        this.tariffAuditRows = []
      } finally {
        this.auditLoading = false
        this.tariffAuditLoading = false
      }
    },
    stateText(value) {
      if (!value) return '—'
      return value.is_enabled ? 'ON' : 'OFF'
    },
    formatDate(value) {
      return value ? new Date(value).toLocaleString() : '—'
    }
  }
}
</script>

<style scoped>
.controls-page { min-height:100vh; color:#f4f6ff; }
.page-head { display:flex; align-items:flex-start; justify-content:space-between; gap:16px; margin-bottom:22px; }
.page-head h1 { color:#f4f6ff; font-size:27px; font-weight:800; margin:4px 0; }
.page-head p { color:#8fa0bd; font-size:12px; margin:0; }
.eyebrow { color:#7ab7ff; font-size:10px; font-weight:800; letter-spacing:1.8px; }
.control-card { border-radius:14px !important; background:#0d172b !important; border-color:rgba(111,142,199,.22) !important; }
.section-title { color:#eff4ff; font-weight:800; font-size:16px; }
.plan-meta { display:flex; flex-wrap:wrap; align-items:center; gap:10px; color:#9aabc6; font-size:11px; }
.category-row { display:grid; grid-template-columns:minmax(110px,1fr) minmax(120px,180px) minmax(230px,320px); align-items:center; gap:14px; padding:12px 0; border-bottom:1px solid rgba(120,145,190,.14); }
.category-name { display:flex; flex-direction:column; gap:4px; }
.category-name strong { color:#edf3ff; font-size:13px; }
.category-name small { color:#8798b5; font-size:9px; }
.rate-edit { display:flex; align-items:center; gap:8px; }
.feature-row { display:flex; align-items:center; justify-content:space-between; gap:14px; padding:11px 0; border-bottom:1px solid rgba(120,145,190,.12); }
.feature-copy { display:flex; flex-direction:column; gap:4px; min-width:0; }
.feature-copy strong { color:#edf3ff; font-size:12px; }
.feature-copy small { color:#8798b5; font-size:10px; line-height:1.45; }
.pending-note { color:#f5bd18; font-size:9px; font-weight:700; }
.group-heading { display:flex; align-items:center; justify-content:space-between; width:100%; margin-right:10px; }
@media(max-width:700px) {
 .page-head { flex-direction:column; }
 .category-row { grid-template-columns:1fr; gap:7px; }
 .rate-edit { max-width:100%; }
}
</style>