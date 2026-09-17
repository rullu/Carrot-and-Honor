// Deterministically transcribe the sealed tables; never synthesize lexical content.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const source = 'docs/design_authority/FCAH_Campaign_Start_Procedural_Cast_Naming_Generator_v1_FINAL_SEALED_2026-09-18.txt';
const text = fs.readFileSync(path.join(root, source), 'utf8').replace(/\r\n/g, '\n');
const definitions = [
    [14, 'western', ['Haldren','Velaine','Carthen','Brevane'], 38],
    [15, 'mediterranean', ['Saleran','Varethi','Corassi'], 34],
    [16, 'northern', ['Skeldren','Vaarnic','Eldskar'], 25],
    [17, 'central', ['Orthean','Selvaran','Drevanic','Vaskari'], 38],
    [18, 'kharven', ['Kharven'], 25],
    [19, 'eastern', ['Averi','Tazhari','Qasren'], 34],
];
const families = {};
for (const [section, family, cultures, expected] of definitions) {
    const body = text.slice(text.indexOf(`\n${section}. `), text.indexOf(`\n${section+1}. `));
    const pools = {cultures, male: [], female: [], lineage: []};
    let pool = '';
    for (const line of body.split('\n')) {
        if (line === 'Male given names:') pool = 'male';
        else if (line === 'Female given names:') pool = 'female';
        else if (/^(Houses|Clans:|Dynasties \/ Houses:|EXPANDED)/.test(line)) pool = 'lineage';
        else if (/^[A-Za-z]+ \| /.test(line) && !line.startsWith('Name |')) {
            const [name, primaryText, rareText] = line.split(' | ');
            const tags = value => value === '—' ? [] : value.split(', ');
            const primary = tags(primaryText), rare = tags(rareText);
            if ([...primary, ...rare].some(c => !cultures.includes(c)) || primary.some(c => rare.includes(c))) throw new Error(line);
            pools[pool].push({name, primary, rare});
        } else if (family === 'kharven' && (/^[A-Z][a-z]+, /.test(line) || (pool === 'lineage' && /^[A-Z][a-z]+$/.test(line)))) {
            for (const name of line.split(', ')) pools[pool].push({name, primary: [], rare: []});
        }
    }
    for (const kind of ['male','female','lineage']) {
        const names = pools[kind].map(e => e.name);
        if (new Set(names).size !== names.length || names.length !== (kind === 'lineage' ? expected : family === 'kharven' ? 15 : 20)) throw new Error(`${family}/${kind}: ${names.length}`);
    }
    families[family] = pools;
}
const seats = {};
for (const match of text.matchAll(/^(R\d{3}) -> P(\d+) /gm)) seats[match[1]] = Number(match[2]);
if (Object.keys(seats).length !== 43) throw new Error('Missing seats');
const data = {generator_version: 1, authority: source, families, seats};
const output = JSON.stringify(data, null, 2) + '\n';
const destination = path.join(root, 'data/campaign/campaign_start_v1.json');
if (process.argv.includes('--check')) {
    if (fs.readFileSync(destination, 'utf8').replace(/\r\n/g,'\n') !== output) throw new Error('Sealed data transcription differs');
} else fs.writeFileSync(destination, output);
console.log('PASS: 230 given-name entries, 194 lineage entries, all affinities and 43 seats match sealed authority.');
