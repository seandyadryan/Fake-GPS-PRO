"""Generate DRAFT catalogs at development time, never from the shipped app.

Uses Google's public translation endpoint (unofficial, no SLA). Transmits ONLY
English UI copy, never user coordinates, saved places, or account data. Review
translations with native speakers before sale. Cached responses are gitignored.
Existing catalogs are not overwritten. Normal builds/tests run fully offline.
"""
import concurrent.futures, hashlib, json, re, time, urllib.parse, urllib.request, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=json.loads((ROOT/'lib/l10n/app_en.arb').read_text(encoding='utf-8'))
KEYS=[k for k in BASE if not k.startswith('@')]
LANGUAGES=json.loads((ROOT/'lib/l10n/languages.json').read_text(encoding='utf-8'))
CACHE=ROOT/'.build/l10n-cache'
CACHE.mkdir(parents=True,exist_ok=True)

def translate(text,target):
    target={'fil':'tl','nb':'no','zh':'zh-CN','zh_Hant':'zh-TW'}.get(target,target)
    digest=hashlib.sha256((target+'\n'+text).encode()).hexdigest()
    cache=CACHE/(digest+'.txt')
    if cache.exists(): return cache.read_text(encoding='utf-8')
    url='https://translate.googleapis.com/translate_a/single?'+urllib.parse.urlencode(dict(client='gtx',sl='en',tl=target,dt='t',q=text))
    for attempt in range(3):
        try:
            request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
            with urllib.request.urlopen(request,timeout=35) as response: data=json.load(response)
            result=''.join(chunk[0] or '' for chunk in data[0])
            if not result.strip(): raise ValueError('Empty translation')
            cache.write_text(result,encoding='utf-8')
            time.sleep(1)
            return result
        except Exception:
            if attempt==2: raise
            time.sleep(2*(attempt+1))

def create(language):
    code=language['code']
    path=ROOT/f'lib/l10n/app_{code}.arb'
    if path.exists(): return f'{code}: existing'
    # Keep ICU placeholders and the product name intact.
    tokens={'{coordinates}':'987654321','{count}':'987654322','Fake GPS PRO':'987654323'}
    protected={k:BASE[k] for k in KEYS}
    for k in KEYS:
        for original,token in tokens.items(): protected[k]=protected[k].replace(original,token)
    batches=[]; current=[]; size=0
    for i,k in enumerate(KEYS):
        line=f'[[[{i:03d}]]] {protected[k]}'
        if size+len(line)>2300 and current: batches.append(current);current=[];size=0
        current.append((i,k,line));size+=len(line)+1
    if current: batches.append(current)
    values={}
    for batch in batches:
        translated=translate('\n'.join(row[2] for row in batch),code)
        chunks=re.split(r'\[\s*\[\s*\[\s*(\d+)\s*\]\s*\]\s*\]',translated)
        found={int(chunks[i]):chunks[i+1].strip() for i in range(1,len(chunks)-1,2)}
        for i,k,line in batch:
            value=found.get(i) if set(found)=={row[0] for row in batch} else None
            if not value: value=translate(protected[k],code).strip()
            for original,token in tokens.items():
                value=re.sub(token,lambda m: original,value,flags=re.I)
            required=set(re.findall(r'\{\w+\}',BASE[k]))
            if set(re.findall(r'\{\w+\}',value))!=required or '98765432' in value:
                value=translate(protected[k],code).strip()
                for original,token in tokens.items(): value=value.replace(token,original)
                if set(re.findall(r'\{\w+\}',value))!=required or '98765432' in value:
                    raise ValueError(f'{code}.{k}: damaged placeholder or brand token')
            if not value or '\n' in value or re.search(r'\[\[|\]\]',value):
                raise ValueError(f'{code}.{k}: empty or merged translation; review manually')
            values[k]=value
    catalog={'@@locale':code,**values}
    for k,v in BASE.items():
        if k.startswith('@') and not k.startswith('@@'): catalog[k]=v
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return f'{code}: complete ({len(values)} messages)'

if __name__=='__main__':
    selected=set(sys.argv[1:])
    languages=[x for x in LANGUAGES if not selected or x['code'] in selected]
    errors=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        jobs={pool.submit(create,language):language['code'] for language in languages}
        for job in concurrent.futures.as_completed(jobs):
            try: print(job.result(),flush=True)
            except Exception as e:
                errors.append(jobs[job]); print(f'FAILED {jobs[job]}: {e}',flush=True)
    if errors: raise SystemExit('Failed locales: '+', '.join(errors))
