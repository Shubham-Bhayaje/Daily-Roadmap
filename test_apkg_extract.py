import zipfile
import sqlite3
import json
import tempfile
import os
import re

apkg_path = r"C:\Users\shubham\Downloads\Docker_Roadmap.apkg"

def clean_html(raw):
    if not raw: return ""
    # replace <br> and </p> with \n
    text = re.sub(r'(?i)<br\s*/?>', '\n', raw)
    text = re.sub(r'(?i)</p>', '\n', text)
    text = re.sub(r'(?i)</div>', '\n', text)
    # remove all remaining tags
    text = re.sub(r'<[^>]+>', '', text)
    # unescape
    text = text.replace('&nbsp;', ' ').replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&').replace('&quot;', '"')
    return text.strip()

with zipfile.ZipFile(apkg_path, 'r') as z:
    temp_dir = tempfile.mkdtemp()
    z.extract('collection.anki2', temp_dir)
    db_path = os.path.join(temp_dir, 'collection.anki2')
    
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    
    c.execute("SELECT models, decks FROM col LIMIT 1")
    models_raw, decks_raw = c.fetchone()
    models = json.loads(models_raw)
    decks = json.loads(decks_raw)
    
    # 1. Deck Name
    root_deck = None
    all_names = [d['name'] for d in decks.values() if d.get('name') and d.get('name') != 'Default']
    for name in all_names:
        if '::' not in name:
            root_deck = name
            break
    if not root_deck and all_names:
        root_deck = all_names[0].split('::')[0]
    print("Resolved Deck Name:", root_deck)
    
    # 2. Model field map
    model_field_map = {}
    for mid, m in models.items():
        flds = sorted(m.get('flds', []), key=lambda x: x.get('ord', 0))
        fld_names = [f.get('name', '').lower() for f in flds]
        
        front_idx = -1
        back_idx = -1
        stage_idx = -1
        
        for idx, fname in enumerate(fld_names):
            if fname in ['front', 'question', 'topic', 'prompt', 'term', 'word']:
                front_idx = idx
            elif fname in ['back', 'answer', 'definition', 'meaning', 'notes', 'explanation']:
                back_idx = idx
            elif fname in ['stage', 'category', 'tag', 'chapter', 'section', 'group']:
                stage_idx = idx
                
        # Fallbacks
        if front_idx == -1:
            # Look for non-stage first
            for idx, fname in enumerate(fld_names):
                if idx != stage_idx and idx != back_idx:
                    front_idx = idx
                    break
        if back_idx == -1:
            for idx, fname in enumerate(fld_names):
                if idx != stage_idx and idx != front_idx:
                    back_idx = idx
                    break
                    
        model_field_map[int(mid)] = {
            'front': front_idx if front_idx != -1 else 0,
            'back': back_idx if back_idx != -1 else (1 if len(flds) > 1 else 0),
            'stage': stage_idx
        }
        print(f"Model {mid} mapping: front={model_field_map[int(mid)]['front']}, back={model_field_map[int(mid)]['back']}, stage={model_field_map[int(mid)]['stage']}")
        
    # 3. Read notes
    c.execute("SELECT id, mid, flds FROM notes LIMIT 10")
    for row in c.fetchall():
        nid, mid, flds = row
        parts = flds.split('\x1f')
        m_map = model_field_map.get(mid, {'front': 0, 'back': 1, 'stage': -1})
        
        f_idx = m_map['front']
        b_idx = m_map['back']
        s_idx = m_map['stage']
        
        front_val = clean_html(parts[f_idx] if f_idx < len(parts) else parts[0])
        back_val = clean_html(parts[b_idx] if b_idx < len(parts) else "")
        stage_val = clean_html(parts[s_idx]) if (s_idx >= 0 and s_idx < len(parts)) else ""
        
        print(f"\n[Note {nid}]")
        print(f"  Stage: {stage_val}")
        print(f"  Front: {front_val[:60]}")
        print(f"  Back:  {back_val[:60]}...")
