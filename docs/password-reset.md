# Réinitialisation du mot de passe (#116)

Depuis « Se connecter », choisir « Mot de passe oublié ? », saisir l’adresse du
compte puis utiliser le lien reçu pour choisir et confirmer un nouveau mot de passe.
Le lien expire après 15 minutes et devient inutilisable après la modification.
Une nouvelle demande remplace également le lien précédent.

Le message de confirmation reste identique pour une adresse connue ou inconnue.
Le mot de passe actuel reste valide tant que la réinitialisation n’est pas terminée.

## En développement

Pour Gmail, copier `config/smtp.local.example.yml` vers `config/smtp.local.yml`.
Remplir `username` avec l’adresse du compte expéditeur et `password` avec un
[mot de passe d’application Google](https://support.google.com/accounts/answer/185833?hl=fr),
puis redémarrer Rails. Le champ `from` utilise cette même adresse lorsqu’il est vide.
La validation en deux étapes doit être activée sur le compte Google pour créer ce
mot de passe. Ne pas utiliser le mot de passe habituel du compte.
Le fichier local est ignoré par Git ; seul le modèle vide est versionné.

Sans configuration SMTP, les e-mails ne sont pas envoyés sur Internet : Rails les écrit dans `tmp/mail/`.
Après une demande pour un compte existant, ouvrir le fichier correspondant à son
adresse et suivre le lien `http://localhost:3000/users/password/edit?...`.
Ces fichiers sont ignorés par Git. Redémarrer le serveur après modification de la
configuration. Les tests utilisent leur propre boîte aux lettres en mémoire.

Pour recevoir les e-mails dans une vraie boîte de réception, renseigner
`SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` et `MAILER_FROM`
dans les variables d’environnement du terminal ou de la configuration Rails de RubyMine,
puis redémarrer le serveur. Les mêmes paramètres SMTP que la production sont utilisés.
Un simple fichier `.env` n’est pas chargé automatiquement par ce projet.

L’adresse saisie dans « Mot de passe oublié ? » doit appartenir à un compte
réel créé avec le formulaire d’inscription. Les comptes de démonstration de la
page Compte ne sont pas des comptes de connexion. Pour une adresse inconnue,
aucun e-mail n’est généré ; le message de confirmation reste volontairement identique.

## En production

Configurer les variables suivantes dans l’environnement du serveur :

| Variable | Valeur attendue |
| --- | --- |
| `MAILER_HOST` | Domaine public de l’application, sans `https://` |
| `MAILER_FROM` | Adresse d’expédition autorisée par le fournisseur SMTP |
| `SMTP_ADDRESS` | Serveur SMTP du fournisseur |
| `SMTP_PORT` | Port STARTTLS, `587` par défaut |
| `SMTP_USERNAME` | Identifiant SMTP |
| `SMTP_PASSWORD` | Mot de passe ou clé SMTP |

Les liens de production utilisent HTTPS. Les identifiants restent dans
l’environnement du serveur. Aucun service SMTP réel n’est configuré dans le dépôt.

Vérification du parcours : `bundle exec rails test test/controllers/password_recovery_test.rb`.
