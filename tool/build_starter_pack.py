#!/usr/bin/env python3
"""Regenerate the bundled starter exercise pack under assets/exercise_library/.

Selects a curated, varied subset of the local free-exercise-db dataset
(bodyweight + dumbbell, with images), flattens the image filenames so Flutter
can bundle them from a single declared directory, and writes a trimmed JSON
that ExerciseLibraryService loads when no full library has been downloaded yet.

Run from the project root:  python tool/build_starter_pack.py
"""
import json
import os
import shutil

SRC = "exercise_library/free_exercise_db/exercises.json"
IMG_ROOT = "exercise_library/free_exercise_db/exercises"
OUT_DIR = "assets/exercise_library"
OUT_IMG = os.path.join(OUT_DIR, "images")
CAP = 24


def main() -> None:
    src = json.load(open(SRC, encoding="utf-8"))

    def ok(e):
        return e.get("equipment") in ("body only", "dumbbell") and len(e.get("images") or []) >= 2

    pool = [e for e in src if ok(e)]
    pool.sort(key=lambda e: {"beginner": 0, "intermediate": 1, "advanced": 2}.get(e.get("level"), 1))

    def primary(e):
        pm = e.get("primaryMuscles") or []
        return pm[0] if pm else ""

    selected, covered = [], set()
    for e in pool:  # one exercise per distinct primary muscle
        pm = primary(e)
        if pm and pm not in covered:
            selected.append(e)
            covered.add(pm)
    for e in [x for x in pool if x.get("category") == "stretching"][:3]:
        if e not in selected:
            selected.append(e)
    for e in [x for x in pool if x.get("category") in ("cardio", "plyometrics")
              and x.get("equipment") == "body only"][:2]:
        if e not in selected:
            selected.append(e)
    selected = selected[:CAP]

    if os.path.isdir(OUT_IMG):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_IMG, exist_ok=True)

    trimmed = []
    for e in selected:
        eid = e["id"]
        rels = []
        for i, rel in enumerate(e["images"][:2]):
            sp = os.path.join(IMG_ROOT, rel)
            if not os.path.exists(sp):
                continue
            fn = f"{eid}_{i}.jpg"
            shutil.copyfile(sp, os.path.join(OUT_IMG, fn))
            rels.append("images/" + fn)
        if not rels:
            continue
        trimmed.append({
            "id": eid, "name": e.get("name", ""), "force": e.get("force") or "",
            "level": e.get("level") or "", "mechanic": e.get("mechanic") or "",
            "equipment": e.get("equipment") or "",
            "primaryMuscles": e.get("primaryMuscles") or [],
            "secondaryMuscles": e.get("secondaryMuscles") or [],
            "instructions": e.get("instructions") or [],
            "category": e.get("category") or "",
            "images": rels, "gif": "", "imageSource": "asset",
        })

    json.dump(trimmed, open(os.path.join(OUT_DIR, "starter_exercises.json"), "w", encoding="utf-8"), indent=1)
    print(f"Wrote {len(trimmed)} starter exercises, {len(os.listdir(OUT_IMG))} images.")


if __name__ == "__main__":
    main()
