import { copyFileSync, existsSync, mkdirSync, readdirSync } from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
let packageJson
try {
  packageJson = require.resolve('maplibre-gl/package.json')
} catch (error) {
  throw new Error('Cannot resolve installed maplibre-gl/package.json: ' + error.message)
}
const dist = path.join(path.dirname(packageJson), 'dist')
const publicDir = path.resolve('public')
const files = ['maplibre-gl-worker.mjs', 'maplibre-gl-shared.mjs']

if (!existsSync(dist)) {
  throw new Error('MapLibre dist directory does not exist: ' + dist)
}
const available = readdirSync(dist)
console.log('Resolved MapLibre package:', packageJson)
console.log('MapLibre dist files:', available.join(', '))

mkdirSync(publicDir, { recursive: true })
for (const file of files) {
  const source = path.join(dist, file)
  if (!existsSync(source)) {
    throw new Error('Required MapLibre worker asset is missing: ' + source)
  }
  copyFileSync(source, path.join(publicDir, file))
  console.log('Copied', file)
}
