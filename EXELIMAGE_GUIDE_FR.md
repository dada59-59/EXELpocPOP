# EXELIMAGE — Guide d'utilisation

Convertit n'importe quelle image en écran EXL100 : un affichage de 40×25 caractères
utilisant les quatre générateurs de caractères (BAGC0 à BAGC3), exporté en assembleur
TMS7000.

Fichier HTML unique — à ouvrir dans un navigateur, sans installation ni serveur.

---

## 1. Ce que l'outil produit

L'écran EXL100 fait 40 colonnes × 25 lignes = **1000 cellules**. Chaque cellule mesure
8×10 pixels et affiche un caractère en deux couleurs (avant-plan + fond).

EXELIMAGE analyse l'image, invente jusqu'à **512 caractères personnalisés**
(128 par banque × 4 banques) et écrit un fichier `.asm` contenant :

| Bloc | Contenu |
|---|---|
| `BAGC0_DATA` … `BAGC3_DATA` | 4 × 128 caractères × 10 octets de bitmap |
| `SCREEN_DATA` | 1000 cellules × 2 octets (octet d'attribut + code caractère) |
| `write_screen` | Routine qui envoie les cellules en VRAM via TRAP 9 |
| Code d'amorçage | Adresses de base des générateurs, mode MIXT, init écran |

Le programme généré est autonome : il suffit de l'assembler pour afficher l'image.

---

## 2. Prise en main

1. **⊕ BROWSE IMAGE** — charger un PNG/JPG. Toute taille ; l'image est ramenée à 320×250.
2. Choisir un **style prédéfini** (voir §3).
3. **◈ PROCESS IMAGE** — la conversion s'exécute, l'aperçu apparaît.
4. Ajuster les réglages, puis **↺ REPROCESS** après chaque modification.
5. Une fois satisfait, l'ASM est généré — à copier ou télécharger.

Surveiller la barre d'état : **BAGC2+BAGC3 : n/256 slots**. Si les banques saturent,
l'image perd du détail — réduire le tramage ou choisir un style plus simple.

---

## 3. Styles prédéfinis

Chaque style règle d'un coup toute une famille de paramètres. Commencer par là,
affiner ensuite.

| Style | Idéal pour |
|---|---|
| **Photorealistic** | Photographies, visages, dégradés |
| **Comics / Cartoon** | Dessins au trait, aplats de couleur |
| **Pop Art** | Contrastes saturés et francs |
| **Black & White** | Monochrome, gravures, fort contraste |
| **Neon / Cyberpunk** | Images sombres à accents lumineux |
| **Thermal / Infrared** | Rendu fausses couleurs type caméra thermique |
| **Posterize** | Bandes de couleurs réduites, effet affiche |
| **Japanese Woodblock** | Estampes, aplats cernés de contours |

---

## 4. Panneau de réglages

### Algorithme de couleur
Chaque cellule ne peut contenir que **deux couleurs**. Ce réglage choisit lesquelles.

- **K-Means 2-color (best)** — regroupe les pixels de la cellule ; meilleure qualité,
  choix par défaut.
- **Dominant 2 colors** — les deux couleurs les plus fréquentes ; rapide, bon sur les aplats.
- **Min+Max luminance** — pixel le plus sombre et le plus clair ; contraste maximal.
- **Best pair (exhaustive)** — teste toutes les paires ; le plus lent, légèrement meilleur
  sur les cellules difficiles.

### Tramage (dithering)
Simule les teintes intermédiaires en alternant les pixels.

- **Threshold (none)** — seuil net. Le plus précis, idéal pour le trait et le texte.
- **Bayer 4×4 / 8×8 ordered** — motif régulier. Bons dégradés, texture visible.
  Le 8×8 est plus fin.
- **Floyd-Steinberg** — diffusion d'erreur. Le plus naturel sur photo, mais génère
  beaucoup de cellules uniques (surveiller le compteur de slots).

### Réglages fins

| Curseur | Plage | Remarques |
|---|---|---|
| Brightness (luminosité) | −100 … +100 | Appliqué avant le tramage |
| Contrast (contraste) | −100 … +100 | L'augmenter aide généralement la lisibilité sur EXL100 |
| Saturation | 0 … 200 | 0 = niveaux de gris |
| Sharpen (netteté) | 0 … 300 | Récupère le détail perdu à la réduction ; trop haut = bruit |
| Dither % | 0 … 100 | Force du tramage ; plus bas = moins de caractères uniques |

### Optimisation des caractères
Répartition du budget de 512 caractères.

- **Greedy (fast)** — premier arrivé, premier servi. Pour les aperçus rapides.
- **K-means cluster (best)** — regroupe les cellules proches et mutualise les caractères.
  Meilleure qualité finale.
- **Halftone (B&W)** — utilise une bibliothèque de trames au lieu de caractères sur mesure.
  Très économe en slots ; à combiner avec le **motif** ci-dessous.

### Motif prédéfini (mode halftone)
`None` (détail maximal), `Bayer`, `Bayer soft`, `Clustered dots`, `Horizontal lines`,
`Vertical lines`. Les motifs de lignes conviennent aux rendus gravure ou bande dessinée.

### Remappage des couleurs
Huit pastilles, une par couleur EXL100. Chacune peut être redirigée vers une autre —
pratique pour corriger une palette mal choisie par la conversion (forcer un fond au noir
par exemple) sans retraiter l'image.

---

## 5. Outils d'aperçu

- **⊞ CELL GRID** — superpose les limites des cellules 8×10. Indispensable pour vérifier
  qu'un visage ou un contour n'est pas coupé entre deux cellules.
- **◧ COMPARE** — source et résultat côte à côte.
- **⊕ 1×** — cycle de zoom pour l'inspection au pixel près.

---

## 6. Onglet éditeur de pixels

Retouche manuelle du résultat, cellule par cellule.

| Outil | Action |
|---|---|
| ✏ PIXEL | Dessiner / effacer des pixels isolés |
| ▣ FILL | Remplissage par zone |
| ⊕ INVERT | Inverser la cellule |
| □ CLEAR | Vider la cellule |
| ← UNDO / → REDO | Historique complet |
| ⊞ GRID | Afficher la grille de pixels |

- **◈ GENERATE ASM** — régénère l'assembleur en intégrant les retouches.
- **↺ RESET TO GENERATED** — annule les retouches, retour à la conversion automatique.
- **⧉ COPY ASM** — copie le source dans le presse-papiers.

Usage typique : la conversion est bonne à 95 %, mais un œil ou une lettre est abîmé —
corriger ces quelques cellules à la main plutôt que tout retraiter.

---

## 7. Persistance des réglages

Chaque `.asm` généré embarque ses réglages dans un bloc de commentaires d'en-tête
(`EXELIMAGE_SETTINGS_BEGIN … END`) : fichier source, style, algorithmes, valeurs de tous
les curseurs et remappage des couleurs.

**⬆ IMPORT SETTINGS FROM ASM** relit ce bloc. Un ancien export peut donc être rouvert
des mois plus tard et retouché, sans avoir à retrouver les réglages qui l'ont produit.

---

## 8. Notes pratiques

- **Budget de slots** : 512 caractères au total. Floyd-Steinberg avec un fort taux de
  tramage sur une photo détaillée les épuise. Si le compteur sature : baisser Dither %,
  passer en Bayer, ou utiliser l'optimisation K-means.
- **Préparer l'image en amont** : recadrer au format 40:25 (1,6:1) dans un éditeur.
  EXELIMAGE redimensionne sans recadrer, une source mal proportionnée sera écrasée.
- **Le contraste prime sur la résolution** : en 320×250 avec deux couleurs par cellule,
  une image très contrastée se lit toujours mieux qu'une image subtile.
- **Bit DC5** : le code généré met DC5 = 1 *après* `set_25LINE`, car cette routine
  réinitialise CM2 = $C8 et efface DC5. Conserver cet ordre en cas de fusion dans un
  programme plus vaste.
- **Fusion avec un autre programme** : le fichier exporté est complet et autonome
  (`start:`, `.org`, `screen_data2`, `#include "mixt_api.asm"`, `.end`). Pour l'intégrer
  à un jeu, ne garder que la configuration des générateurs, les données de caractères,
  `SCREEN_DATA` et `write_screen`, et supprimer les sections d'amorçage et de fin en double.
