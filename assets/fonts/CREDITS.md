# Créditos y licencias de fuentes

| Archivo | Fuente | Autor | Licencia | Uso |
| --- | --- | --- | --- | --- |
| `PixelOperator.ttf` | Pixel Operator | Jayvee Enaguas (HarvettFox96) | [CC0 1.0](PixelOperator-CC0.txt) | Texto, botones y filas (`UiTokens.FONT_BODY`, 16 px) |
| `PixelOperator8.ttf` | Pixel Operator 8 | Jayvee Enaguas (HarvettFox96) | [CC0 1.0](PixelOperator-CC0.txt) | Pistas y textos del juego (`UiTokens.FONT_SMALL`, 8 px) |
| `Jersey10-Regular.ttf` | Jersey 10 | Sarah Cadigan-Fried (The Soft Type Project) | [SIL OFL 1.1](Jersey10-OFL.txt) | Títulos, logo y carteles (`UiTokens.FONT_DISPLAY`, 19 y 38 px) |

- Pixel Operator se tomó de la copia CC0 de
  [ericoporto/pixel-utf8-fonts](https://github.com/ericoporto/pixel-utf8-fonts).
  CC0 no exige crédito; se deja igual por cortesía.
- Jersey 10 viene de [google/fonts](https://github.com/google/fonts/tree/main/ofl/jersey10).
  La OFL permite usarla y distribuirla con el juego; el archivo de licencia
  tiene que viajar con la fuente y no se puede vender la fuente sola.

Las tres se importan sin antialias, sin hinting y sin posicionamiento
subpíxel (`*.ttf.import`, versionados a propósito) y solo se usan a los
tamaños de `UiTokens`, para que cada pixel de la letra caiga en un pixel de
pantalla. `scripts/ui/test_ui_theme.gd` lo verifica.
