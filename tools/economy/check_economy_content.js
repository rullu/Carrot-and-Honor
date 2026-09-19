// Developer transcription check: the sealed document remains the design authority.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const authorityPath = path.join(root, 'docs/design_authority/FCAH_Province_Economy_Production_Discovery_v1_FINAL_SEALED_IMPLEMENTATION_AUTHORITY_2026-09-19.txt');
const bytes = fs.readFileSync(authorityPath);
if (crypto.createHash('sha256').update(bytes).digest('hex') !== '556c38e250deac9fde1dd61831336256875d0470246a96d29fd45c78ffb5b799') throw Error('Sealed authority fingerprint changed');
const text = bytes.toString('utf8').replace(/\r\n/g, '\n');
const section = (start, end) => text.slice(text.indexOf('\n' + start), text.indexOf('\n' + end));
const numbered = block => [...block.matchAll(/^\d+\. (.+)$/gm)].map(m => m[1]);
const opportunities = numbered(section('6. ACTIVE GENERATED', '7. IMPORTANT RESOURCE')).slice(1);
const buildingText = section('13. STRATEGIC CITY', '14. CAMPAIGN-START STRATEGIC');
const buildings = [...buildingText.matchAll(/^TRUE FAMILIES\n((?:- .+\n)+)/gm)].flatMap(m => m[1].trim().split('\n').map(s => s.slice(2)));
const startText = section('14. CAMPAIGN-START STRATEGIC', '15. LOCAL SOURCE');
const pool = numbered(startText.slice(startText.indexOf('EXACT NORMAL DAY-1'), startText.indexOf('HARD ELIGIBILITY')));
const data = JSON.parse(fs.readFileSync(path.join(root, 'data/economy/economy_catalogue_v1.json')));
const equalSet = (actual, expected, label) => {
  if (new Set(actual).size !== actual.length || JSON.stringify(actual.sort()) !== JSON.stringify(expected.sort())) throw Error(label + ' transcription mismatch');
};
equalSet(data.definitions.filter(d=>d.kind==='opportunity').map(d=>d.display_name), opportunities, 'Opportunities');
equalSet(data.definitions.filter(d=>d.kind==='building').map(d=>d.display_name), buildings, 'City families');
equalSet(data.definitions.filter(d=>d.kind==='building' && d.day_one_random).map(d=>d.display_name), pool, 'Day-1 pool');
const ids = new Set(data.definitions.map(d=>d.definition_id));
if (ids.size !== data.definitions.length || opportunities.length !== 26 || buildings.length !== 37 || pool.length !== 13) throw Error('Catalogue count/identity mismatch');
const sites = data.definitions.filter(d=>d.kind==='site');
if (sites.length !== 32 || sites.filter(s=>s.source_id==='opportunity_fertile_land').length !== 6 || sites.filter(s=>s.source_id==='aquatic').length !== 1) throw Error('Countryside family mapping mismatch');
for (const opportunity of data.definitions.filter(d=>d.kind==='opportunity')) {
  const count = sites.filter(s=>s.source_id===opportunity.definition_id).length;
  if (count !== (opportunity.definition_id==='opportunity_fertile_land' ? 6 : 1)) throw Error('Site source mapping: ' + opportunity.definition_id);
}
console.log('PASS: sealed SHA-256; 26 opportunities, 32 countryside types, 37 strategic families, exact 13-type Day-1 pool.');
