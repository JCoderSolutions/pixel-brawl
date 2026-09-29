# Créditos y licencias de audio

## Efectos (`assets/audio/sfx/*.wav`)

| Archivo | Fuente | Licencia |
| --- | --- | --- |
| `punch`, `hit`, `ricochet`, `shot`, `shotgun`, `swing`, `throw`, `explosion`, `block_hit`, `block_break`, `jump`, `land`, `death`, `pickup`, `dry_fire` | Generados por `assets/audio/generate_sfx.py` (síntesis procedural estilo sfxr, sin samples externos) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

Son obra original del proyecto: no hay que dar crédito a terceros y se pueden
usar, modificar y redistribuir sin restricciones. Para cambiar un sonido se
edita su receta en `generate_sfx.py` y se vuelve a correr:

```bash
python3 assets/audio/generate_sfx.py
```

Formato: WAV mono, 16 bit, 22 050 Hz (≈170 KB en total).

## Música (`assets/audio/music/*.wav`)

| Archivo | Fuente | Licencia |
| --- | --- | --- |
| `menu` (100 BPM, La menor, 8 compases), `battle` (150 BPM, Mi menor, 16 compases) | Generadas por `assets/audio/generate_music.py` (chiptune procedural: pulso, triángulo y ruido, sin samples externos) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

Para cambiar una pista se edita su función en `generate_music.py` y se vuelve
a correr:

```bash
python3 assets/audio/generate_music.py
```

Formato: WAV mono, 16 bit, 22 050 Hz. Godot las importa en loop y comprimidas
con IMA-ADPCM (opciones en los `.wav.import`, que sí se versionan). Si se
agregan pistas de terceros, **solo con licencia CC0** y anotadas en esta tabla
con su URL.
