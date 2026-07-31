# EXLCHAR v11 — Guide d'utilisation

Éditeur de caractères, animateur de sprites et éditeur de niveaux pour EXL100, générant
un moteur de jeu TMS7000 complet (`engine.asm`) et les données de niveau (`level.h`).

Fichier HTML unique — à ouvrir dans un navigateur, sans installation ni serveur.

---

## 1. Vue d'ensemble

EXLCHAR couvre trois tâches liées :

| Zone | Rôle |
|---|---|
| **Éditeur de caractères** | Les 128 caractères redéfinissables de 8×10 (banque BAGC1) |
| **Éditeur d'animations** | Sprites multi-cellules, images, affectation des touches |
| **Éditeur de niveau** | Une carte de tuiles 40×25 avec sa bibliothèque de tuiles |

**EXPORT ASM** produit un moteur fonctionnel : il programme les générateurs vidéo, charge
les caractères, dessine le niveau, lit le clavier et anime le sprite. **EXPORT .H FILE**
(onglet niveau) produit les données de niveau incluses par le moteur.

Le travail est sauvegardé automatiquement dans le navigateur — **RESTORE** rappelle la
dernière session. **SAVE JSON** / **LOAD JSON** pour de vraies sauvegardes (à utiliser :
le stockage navigateur n'est pas un coffre-fort).

---

## 2. Caractères

La grille de base contient 128 caractères de 8×10 pixels, chacun avec une couleur
d'avant-plan et de fond. Ce sont les briques élémentaires : les cellules de sprite comme
les tuiles y font référence.

Deux emplacements sont réservés par le matériel et jamais alloués : **$20** et **$7F**
(vide). Budget utilisable : **126 emplacements par banque**.

---

## 3. Animations

### Structure

Une animation possède un nom, une **touche**, un indicateur **default**, et une liste
d'images. Une image est un rectangle de cellules (colonnes × lignes), chaque cellule
étant un caractère 8×10.

| Champ | Signification |
|---|---|
| **key** | NONE, LEFT, RIGHT, UP, DOWN, SPACE, ENTER |
| **default** | L'animation de repos, jouée quand aucune touche n'est pressée |
| **x_off** | Décalage horizontal de cette image, en colonnes |
| **duration** | Durée d'affichage en trames VBL (voir §7) |
| **x_advance** | Colonnes gagnées par cycle d'animation (voir §6) |

> **Règle essentielle — l'animation par défaut doit avoir key = NONE.**
> Une animation par défaut associée à une touche se déplace toute seule sans qu'aucune
> touche ne soit pressée : le répartiteur de repos la relance à chaque tour et chaque
> passage exécute son pas de déplacement. L'exportateur refuse désormais cette
> configuration et en explique la raison.

### Import de sprites

**IMPORT IMG** charge une planche de sprites ; positionner la fenêtre de capture sur une
pose puis **⬇ CAPTURE → FRAME** la transforme en image dans l'animation choisie. Répéter
pour chaque pose.

### Éditeur de pixels d'image

Sélectionner une vignette d'image rend l'aperçu modifiable :

- **Clic gauche / glisser** — dessiner · **Clic droit / glisser** — effacer
- **Zoom** 2× / 4× / 6× / 8× ; la grille de pixels apparaît à partir de 4×
- **Les lignes bleues** marquent les limites des caractères 8×10 — éviter qu'un détail
  chevauche deux cellules, chaque chevauchement coûte des emplacements supplémentaires
- **FLIP H** — miroir de l'image (construire une marche à gauche depuis celle de droite)
- **◀ ▶ ▲ ▼** — décaler *tous* les pixels d'un pixel, en traversant les limites de
  cellules. Idéal pour réaligner une capture importée. Les pixels sortis du cadre sont perdus
- **CLEAR** — vider l'image

### Opérations sur les images

| Bouton | Effet |
|---|---|
| **◀ MOVE / MOVE ▶** | Déplacer l'image plus tôt / plus tard dans la séquence |
| **DUP+** | Dupliquer juste après elle, les suivantes se décalent |
| **COPY→END** | Copier à la fin de la même animation |
| **COPY TO→** | Copier vers une autre animation (à choisir dans la liste) |
| **DELETE FRAME** | Supprimer |

Méthode conseillée pour une marche en miroir : pour chaque image de la marche à droite —
**COPY TO→** WALK_LEFT, puis **FLIP H**, puis **MOVE** pour la placer.

---

## 4. Éditeur de niveau

### Onglet PAINT

- Grille de 40 colonnes × 25 lignes ; **clic gauche** peint la tuile sélectionnée,
  **clic droit** efface la cellule (vide)
- **Palette de tuiles** : **+ TILE** en ajoute une, **DEL** supprime la sélection,
  **PRUNE** supprime toutes les tuiles non utilisées dans la grille et renumérote la carte
- **Tampons (stamps)** : blocs multi-cellules ; en sélectionner un et cliquer pose tout le bloc
- **− / +** zoom, **CLEAR** vide la carte
- **SAVE JSON / LOAD JSON** — sauvegarde du niveau (contient aussi les bitmaps des tuiles)

Cliquer une tuile dans la palette quitte le mode tampon ; le clic droit efface toujours
une seule cellule, quel que soit le mode.

### Onglet TILE IMPORT

**📁 LOAD IMAGE** → positionner/zoomer (**FIT EXL100** ajuste à l'écran) →
**EXTRACT → TILE LIBRARY**. La zone d'image est découpée en cellules 8×10, dédoublonnée,
puis transformée en tuiles et en un tampon du bloc entier. Les tuiles sont nommées
`<bloc>_<code>`.

### La case « solid (blocks movement) »

Marque la tuile comme solide dans la table `TILE_SOLID` exportée. **Le moteur actuel ne
l'utilise pas encore** — c'est une donnée préparée pour la future détection de collisions
(murs infranchissables, sols). La cocher modifie deux lignes de `level.h` et rien à l'écran.

### Octet d'attribut

`BF GF RF | CG1 CG0 | BB GB RB` — les trois bits de poids fort sont la **couleur
d'avant-plan**, les bits 3–4 sélectionnent le **générateur**. Ainsi `$F8`, `$B8`, `$98`…
sont toutes des tuiles BAGC3 de couleurs différentes. Seul le champ générateur sert à
classer une tuile.

L'export prévient lorsqu'une tuile utilisée dans la carte serait invisible : bitmap vide,
caractère BAGC1 non dessiné, ou générateur non pris en charge.

---

## 5. Le moteur exporté

### Structure

```
équates → config générateurs → chargement caractères → dessin du niveau
main_loop → lecture clavier → répartition des animations
play_anim_N → par image : déplacement, dessin, temporisation, test touche
run_celllist / bg_restore_cell / erase_n_cols   (exécuteurs à l'exécution)
tables d'opérations (dtb_N / ttb_N) + ALL_CHARS + ALL_CHARS2
```

### Transitions plutôt qu'effacer-puis-redessiner

Pour chaque paire d'images consécutives, l'exportateur calcule à l'avance exactement
quelles cellules changent, et le stocke sous forme de **table** d'opérations de 4 octets
`[colonne, ligne, attribut, code]`. Une cellule identique dans les deux images ne génère
rien du tout ; une cellule libérée est repeinte depuis la carte du niveau. Résultat :
aucun scintillement, environ deux fois moins d'écritures vidéo.

Les dessins complets (`dtb_N`) servent à l'entrée dans une animation depuis une autre.

### Deux banques de caractères

Les sprites utilisent **BAGC1** (attribut `$F0`, 126 emplacements). Au-delà, l'exportateur
ouvre automatiquement **BAGC2** (attribut `$E8`, base `$0A00`), soit un budget total de
**252 cellules uniques**. Au-delà encore, l'export s'interrompt avec un décompte par
animation.

`ALL_CHARS2` et son code de chargement n'apparaissent que si nécessaire.

### Sécurité vis-à-vis des interruptions

Le gestionnaire d'interruption de la ROM ne préserve que les registres A et B : tout ce
qui est en R5 et au-delà est détruit silencieusement à chaque appui touche. Toutes les
routines conservant un état dans TEMP1–4 sont encadrées par `dint` / `eint`.

---

## 6. Déplacement : filmstrip ou classique

L'exportateur détecte deux façons d'encoder le déplacement et génère le code adapté.

**Classique** — toutes les images ont `x_off = 0`. `PLAYER_X` avance d'une colonne par
image. Simple, adapté aux animations dessinées à la main.

**Filmstrip (pellicule)** — les images portent des `x_off` croissants (typique d'une
planche de sprites capturée, ex. 0,0,1,1,2,3,…,9). Ici le déplacement est *déjà dans les
données* : le sprite est dessiné en `PLAYER_X + x_off`, et `PLAYER_X` lui-même ne bouge
pas pendant le cycle. Au retour à l'image 0, il rattrape en un seul pas de
**x_advance** colonnes.

**x_advance** réconcilie donc `PLAYER_X` avec la distance déjà parcourue par les x_off.
Valeur par défaut = *x_off de la dernière image + 1*, ce qui fait du bouclage une foulée
normale d'une colonne. À ne pas modifier sauf si le bouclage paraît faux ; une valeur ≤ 0
signifie « automatique ».

Le moteur replie `x_off` dans `PLAYER_X` à chaque frontière — entrée, sortie, mur — de
sorte que la position logique et la position dessinée ne peuvent jamais diverger.

---

## 7. Vitesse d'animation

`FRAMES_PER_STEP` (une équate en tête de `engine.asm`) fixe le nombre de trames VBL que
dure chaque pas. Elle est générée à partir de la **durée la plus fréquente** de la
session : modifier cette seule ligne re-cadence donc toute l'animation.

| Valeur | Vitesse |
|---|---|
| 1 | ~50 pas/s |
| 2 | ~25 pas/s |
| 3 | ~16 pas/s |
| 4 | ~12 pas/s |

Une image dont la **duration** diffère de cette valeur majoritaire émet sa propre valeur
littérale et prime sur l'équate. C'est ainsi qu'on tient une pose plus longtemps —
bien plus économique que dupliquer l'image, qui coûte ~110 octets de code de séquencement.

---

## 8. Assemblage et test

Assembler avec TASM : `tasm -tEXL -a -b engine.asm`.
Garder `level.h` et `mixt_api.asm` dans le même répertoire.

Règle d'ordre : **toutes les directives `#DEFINE` et `#include` doivent suivre `.org`**.
Un `#include "level.h"` placé avant ferait atterrir les données de tuiles dans le fichier
de registres ($0000–$007F).

Si le programme dépasse l'espace disponible à `.org $1000`, le déplacer à `.org $0200`
(la fenêtre cartouche s'étend de $0200 à $7FFF).

### Option de débogage

La case **key debug** à côté de EXPORT ASM fait afficher au moteur la valeur de `VALUE0`
(registre clavier) en deux chiffres hexadécimaux en haut à droite. Valeurs au repos :
`$86` EXL100, `$89` Exeltel, `$04` touche relâchée, `$00` démarrage. Utile lorsque le
sprite réagit à des touches non pressées.

---

## 9. Dépannage

| Symptôme | Cause probable |
|---|---|
| Le sprite bouge sans appui touche | L'animation par défaut a une touche — la mettre à NONE |
| Le sprite recule de plusieurs colonnes à chaque cycle | Export ancien ; le mode filmstrip corrige cela |
| Le sprite se téléporte au premier appui | Export ancien ; l'avance de bouclage passait avant le test d'entrée |
| Niveau vide sur le matériel | Une tuile est invisible — lire l'avertissement d'export |
| Les cellules affichent le caractère du dessus | Décalage d'emplacement TRAP 19 (`TEMP7` doit valoir `$00`) |
| Boucle de popups « too many unique cells » | Export ancien ; la limite est désormais 252 avec un seul message |
| « Range of relative branch exceeded » | Saut conditionnel au-delà de ±127 octets — nécessite un tremplin `br` |
| Aperçus de tuiles vides après rechargement | Recharger le JSON du niveau : les tampons portent les bitmaps |

---

## 10. Méthode de travail conseillée

1. Dessiner ou importer les poses du sprite → animations
2. Régler les touches, une animation en **default avec key = NONE**
3. Construire le niveau : importer les tuiles, peindre, **PRUNE**
4. **EXPORT .H FILE** (niveau) puis **EXPORT ASM** (moteur)
5. Assembler, tester à l'émulateur, puis sur matériel réel
6. **SAVE JSON** pour la session et pour le niveau

Conserver des versions numérotées de l'ASM (engine1, engine2, …) plutôt que d'écraser :
comparer deux exports est le moyen le plus rapide de voir ce qu'une modification a
réellement changé.
