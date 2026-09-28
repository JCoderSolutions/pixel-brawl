# Créditos y licencias de audio

## Efectos (`assets/audio/sfx/*.wav`)

| Archivo | Fuente | Licencia |
| --- | --- | --- |
| `punch`, `hit`, `ricochet`, `shot`, `shotgun`, `swing`, `throw`, `explosion`, `block_hit`, `block_break`, `jump`, `land`, `death`, `pickup` | Generados por `assets/audio/generate_sfx.py` (síntesis procedural estilo sfxr, sin samples externos) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

Son obra original del proyecto: no hay que dar crédito a terceros y se pueden
usar, modificar y redistribuir sin restricciones. Para cambiar un sonido se
edita su receta en `generate_sfx.py` y se vuelve a correr:

```bash
python3 assets/audio/generate_sfx.py
```

Formato: WAV mono, 16 bit, 22 050 Hz (≈170 KB en total).

## Música

Todavía no hay pistas. `AudioManager.play_music()` ya existe y usa el bus
`Music`. Fuentes gratuitas recomendadas, **solo con licencia CC0** para no
tener que gestionar créditos:

- [Kenney — Audio](https://kenney.nl/assets/category:Audio) (CC0)
- [OpenGameArt](https://opengameart.org/) filtrando por CC0
- Chiptune propio con [BeepBox](https://www.beepbox.co/) o [jsfxr](https://sfxr.me/)

Toda pista o efecto que se agregue va en la tabla de arriba con su URL y licencia.
