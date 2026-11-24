# Le Prix

Addon pour **World of Warcraft: Forever** qui affiche dans les infobulles le prix de vente des objets à l'hôtel des ventes, net de la commission.

## Fonctionnalités

- **Prix dans les infobulles** : valeur nette (moins 5 % de commission), prix pour vendre maintenant (prix le plus bas moins 1 cuivre, net) et âge du relevé.
- **Scan automatique des sacs** à l'ouverture de l'HV. Seuls les objets vendables sont recherchés, et ceux relevés il y a moins de 15 minutes sont ignorés.
- **Cache des prix** partagé entre tous les personnages du compte de jeu, séparé par région et faction.
- **Liste de surveillance** dans un panneau à droite de l'HV : glisse un objet dedans pour l'ajouter. Le panneau affiche la valeur, l'évolution depuis le relevé précédent et la date.
- **Bouton « Mes persos »** : scanne les objets (sacs et banque) de tous tes personnages de la faction, tels qu'enregistrés à leur dernière connexion.

### Calcul des prix

| Type d'objet | Valeur affichée |
|---|---|
| Marchandises (minerai, herbes, tissu…) | Moyenne pondérée des 200 unités les moins chères |
| Équipement | Médiane des 5 annonces les moins chères, par suffixe aléatoire |

Tes propres annonces sont exclues du calcul.

## Installation

```sh
cd "World of Warcraft/_forever_/Interface/AddOns"
git clone https://github.com/GMercat/LePrix.git LePrix
```

Pour mettre à jour : `git pull` dans ce dossier, puis `/reload` en jeu.

Si l'addon apparaît comme « périmé » ou « incompatible » après un patch, remplace la valeur `## Interface` de `LePrix.toc` (16001 pour le client 1.60.1) par le résultat de `/run print(select(4, GetBuildInfo()))`.

## Commandes

| Commande | Effet |
|---|---|
| `/lp add [lien]` · `/lp del [lien]` | Ajoute ou retire un objet de la liste de surveillance |
| `/lp scan` | Force le scan des sacs (HV ouvert) |
| `/lp persos` | Liste les personnages enregistrés et la date de leurs sacs et banque |
| `/lp oublier Nom` | Retire un personnage |
| `/lp reset` | Vide le cache des prix du marché courant |
| `/lp debug` | Diagnostic : version du client, persistance, API disponibles |

`/leprix` fonctionne aussi à la place de `/lp`.

## Tests

Les tests chargent l'addon dans un environnement WoW simulé (Lua 5.1 via [lupa](https://pypi.org/project/lupa/)) et rejouent un passage à l'HV.

```sh
pip install lupa
python3 tests/run.py .
```

Ils tournent aussi à chaque push grâce à GitHub Actions.

## Limites connues

- L'API utilisée est celle de l'HV retail (`C_AuctionHouse`) : son comportement exact sur le client Forever reste à valider.
- Les SavedVariables sont signalées comme peu fiables sur le client Forever actuel. `/lp debug` indique si les données persistent entre deux sessions.

## Licence

[MIT](LICENSE)
