import { MagnifyingGlassIcon, CalendarDaysIcon, ArrowPathIcon, FunnelIcon } from '@heroicons/react/24/outline'

const MODE_OPTIONS = [
  { value: 'all', label: 'Tous les modes' },
  { value: 'stock', label: 'Stock' },
  { value: 'vente', label: 'Vente' },
  { value: 'promo', label: 'Promo' },
]

const QUICK_PERIODS = [
  { value: 'all', label: 'Toutes les dates' },
  { value: '7', label: '7 derniers jours' },
  { value: '30', label: '30 derniers jours' },
  { value: '90', label: '90 derniers jours' },
]

function FilterPanel({
  mode,
  onModeChange,
  values,
  onChange,
  onApply,
  onClear,
  categoryOptions = [],
  productOptions = [],
  statusOptions = [],
}) {
  return (
    <div className="glass-effect rounded-3xl p-6 mb-8 border border-white/10 shadow-2xl">
      <div className="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between mb-6">
        <div>
          <p className="text-sm uppercase tracking-[0.3em] text-future-400 mb-2">Filtres</p>
          <h2 className="text-2xl font-bold text-white">Affinez vos résultats</h2>
          <p className="text-future-400 text-sm">Filtrer par date, catégorie, produit et modes.</p>
        </div>

        <div className="flex flex-wrap items-center gap-2 rounded-full border border-white/10 bg-white/5 p-2">
          {MODE_OPTIONS.map(option => (
            <button
              key={option.value}
              type="button"
              onClick={() => onModeChange(option.value)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition-all duration-300 ${
                mode === option.value
                  ? 'bg-fopcam-500 text-white shadow-lg shadow-fopcam-500/20'
                  : 'text-future-300 hover:bg-white/10 hover:text-white'
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      <div className="grid gap-4 xl:grid-cols-[1.3fr_0.7fr]">
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <label className="space-y-2">
            <span className="text-sm font-medium text-future-300">Du</span>
            <input
              type="date"
              value={values.from}
              onChange={e => onChange('from', e.target.value)}
              className="w-full rounded-3xl border border-white/10 bg-future-900/70 px-4 py-3 text-white transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
            />
          </label>
          <label className="space-y-2">
            <span className="text-sm font-medium text-future-300">Au</span>
            <input
              type="date"
              value={values.to}
              onChange={e => onChange('to', e.target.value)}
              className="w-full rounded-3xl border border-white/10 bg-future-900/70 px-4 py-3 text-white transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
            />
          </label>
          <label className="space-y-2">
            <span className="text-sm font-medium text-future-300">Période rapide</span>
            <select
              value={values.quick}
              onChange={e => onChange('quick', e.target.value)}
              className="w-full rounded-3xl border border-white/10 bg-future-900/70 px-4 py-3 text-white transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
            >
              {QUICK_PERIODS.map(option => (
                <option key={option.value} value={option.value} className="bg-future-900 text-white">{option.label}</option>
              ))}
            </select>
          </label>
        </div>

        <div className="flex flex-col gap-3 xl:justify-center">
          <div className="flex gap-3">
            <button
              type="button"
              onClick={onApply}
              className="inline-flex items-center justify-center rounded-3xl bg-fopcam-500 px-6 py-3 text-sm font-semibold text-white shadow-lg shadow-fopcam-500/20 transition-all duration-300 hover:bg-fopcam-400"
            >
              <ArrowPathIcon className="mr-2 h-5 w-5" />
              Appliquer
            </button>
            <button
              type="button"
              onClick={onClear}
              className="inline-flex items-center justify-center rounded-3xl border border-white/10 bg-white/5 px-6 py-3 text-sm font-semibold text-future-300 transition-all duration-300 hover:bg-white/10"
            >
              Effacer
            </button>
          </div>
          <div className="rounded-3xl border border-white/10 bg-future-950/50 p-4 text-sm text-future-400">
            <div className="flex items-center gap-2 font-semibold text-white mb-2">
              <FunnelIcon className="h-5 w-5 text-fopcam-400" />
              Filtres actifs
            </div>
            <p>{values.search ? `Recherche : «${values.search}»` : 'Aucun filtre de recherche'}</p>
          </div>
        </div>
      </div>

      <div className="grid gap-4 mt-6 xl:grid-cols-3">
        <label className="space-y-2">
          <span className="text-sm font-medium text-future-300">Par statut</span>
          <select
            value={values.status}
            onChange={e => onChange('status', e.target.value)}
            className="w-full rounded-3xl border border-white/10 bg-future-900/70 px-4 py-3 text-white transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
          >
            <option value="all" className="bg-future-900 text-white">Tout</option>
            {statusOptions.map(option => (
              <option key={option.value} value={option.value} className="bg-future-900 text-white">{option.label}</option>
            ))}
          </select>
        </label>
        <label className="space-y-2">
          <span className="text-sm font-medium text-future-300">Par catégorie</span>
          <select
            value={values.category}
            onChange={e => onChange('category', e.target.value)}
            className="w-full rounded-3xl border border-white/10 bg-future-900/70 px-4 py-3 text-white transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
          >
            <option value="all" className="bg-future-900 text-white">Tout</option>
            {categoryOptions.map(option => (
              <option key={option.value} value={option.value} className="bg-future-900 text-white">{option.label}</option>
            ))}
          </select>
        </label>
        <label className="space-y-2">
          <span className="text-sm font-medium text-future-300">Par produit</span>
          <select
            value={values.product}
            onChange={e => onChange('product', e.target.value)}
            className="w-full rounded-3xl border border-white/10 bg-future-900/70 px-4 py-3 text-white transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
          >
            <option value="all" className="bg-future-900 text-white">Tout</option>
            {productOptions.map(option => (
              <option key={option.value} value={option.value} className="bg-future-900 text-white">{option.label}</option>
            ))}
          </select>
        </label>
      </div>

      <div className="mt-6 grid gap-4 md:grid-cols-[1.5fr_1fr]">
        <label className="relative block">
          <span className="sr-only">Rechercher</span>
          <MagnifyingGlassIcon className="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-future-400" />
          <input
            type="search"
            placeholder="Rechercher nom, catégorie, code-barres..."
            value={values.search}
            onChange={e => onChange('search', e.target.value)}
            className="w-full rounded-3xl border border-white/10 bg-future-900/70 py-3 pl-12 pr-4 text-white placeholder-future-500 transition-all duration-300 focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
          />
        </label>

        <div className="rounded-3xl border border-dashed border-white/10 bg-future-950/50 p-4 flex items-center gap-3">
          <CalendarDaysIcon className="h-6 w-6 text-fopcam-400" />
          <div>
            <p className="text-sm text-future-300">Mode</p>
            <p className="font-semibold text-white">{MODE_OPTIONS.find(item => item.value === mode)?.label}</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default FilterPanel
