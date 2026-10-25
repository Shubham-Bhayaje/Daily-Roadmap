import zipfile
import sqlite3
import json
import tempfile
import os

apkg_path = r"C:\Users\shubham\Downloads\Docker_Roadmap.apkg"

with zipfile.ZipFile(apkg_path, 'r') as z:
    print("Files in apkg:", z.namelist())
    temp_dir = tempfile.mkdtemp()
    z.extract('collection.anki2', temp_dir)
    db_path = os.path.join(temp_dir, 'collection.anki2')
    
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    
    # 1. Check col
    c.execute("SELECT models, decks FROM col")
    models_raw, decks_raw = c.fetchone()
    models = json.loads(models_raw)
    decks = json.loads(decks_raw)
    
    print("\n--- DECKS ---")
    for did, d in decks.items():
        print(f"ID {did}: {d.get('name')}")
        
    print("\n--- MODELS ---")
    for mid, m in models.items():
        fld_names = [f['name'] for f in m['flds']]
        print(f"Model ID {mid}: {m.get('name')} -> Fields: {fld_names}")
        
    print("\n--- SAMPLE NOTES (first 5) ---")
    c.execute("SELECT id, mid, flds, tags FROM notes LIMIT 5")
    for row in c.fetchall():
        nid, mid, flds, tags = row
        parts = flds.split('\x1f')
        print(f"Note {nid} (mid {mid}): parts count={len(parts)}")
        for i, p in enumerate(parts):
            print(f"  Field {i}: {p[:60]}")

    print("\n--- TOTAL CARDS & NOTES ---")
    c.execute("SELECT COUNT(*) FROM notes")
    print("Total notes:", c.fetchone()[0])
    c.execute("SELECT COUNT(*) FROM cards")
    print("Total cards:", c.fetchone()[0])
