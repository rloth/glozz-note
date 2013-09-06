Utilisation de glozz-note.pl
============================

-------------------------------------------------------------------------
Glozz-note est un script perl pour le post-traitement basique de corpus
annotés sous la plate-forme GLOZZ du laboratoire GREYC (projet Annodis).

Contenu :
  1. Présentation
  2. Installation des modules perl
  3. Formats de sortie

L'encodage des documents et la locale sont supposés réglés sur UTF-8.

-------------------------------------------------------------------------

1. Présentation
=================

Le lancement s'effectue en ligne de commande. Il n'y a pas d'installation
spécifique à effectuer, exceptés les modules perl détaillés au §2.

Usage :
  perl glozz-note.pl -A chemin/corpus.aa -C chemin/corpus.ac

Aide :
  perl glozz-note.pl --help

Glozz-note effectue une récupération des unités annotées avec leur type,
le contenu textuel et les attributs associés.

Glozz-note convient particulièrement aux annotations qui présentent des
imbrications successives (dans une logique Section::Phrase::mot).

Ainsi, pour toute unité d'annotation, on va :
  - récupérer depuis le corpus le segment de texte lié à l'annotation
  - relever ses attributs *non vides*
  - reconstituer toute imbrication d'une unité dans une autre comme des
    arborescences (sauf indication contraire)
  - mettre en forme les resultats pour la sortie voulue (cf. §3)

NB: Dans cette version, le script ignore les annotations de "relations"
    et de "schémas". Seules les "unités" glozz sont prises en compte.

Le script voit par défaut les unités comme un arbre d'imbrications
(elle est relevée sur la base de la position de départ).

L'arborescence peut à la rigueur être ignorée pour des annotations qui
comportent beaucoup de chevauchements (option -n), au prix de quelques
colonnes non spécifiées dans le tableau.

2. Installation des modules perl
================================

Pour vérifier la version de votre perl, lancer :
  perl -v

Il est conseillé d'utiliser un interpreteur perl d'une version >= 5.8

Ensuite 2 modules sont requis : XML::Simple et Data::Diver

Pour les installer (si ce n'est pas déjà le cas), le plus simple est
habituellement d'utiliser la commande 'cpan'.

C'est-à-dire :
  sudo cpan XML::Simple
  sudo cpan Data::Diver

cpan télécharge les modules, puis configure et compile ce qu'il faut.

NB: Si c'est la 1ère utilisation de cpan sur la machine, il va chercher
    à se configurer : en gros il faut taper ENTER à chaque question puis
    tout à la fin choisir un ou des serveur(s) parmi la liste proposée.


3. Formats de sortie
=====================

Trois formats de sortie sont disponibles :
  - (par défaut) mode "listing"
  - (option -t)  mode "tableau"
  - (option -x)  mode "pseudo-xml"

listing
-------
Le format listing est approprié pour un premier aperçu des résultats de
l'annotation. Chaque unité est présentée sous la forme :

        [sonType]--{sesAttributs}--@(début..fin)
          << ligne_de_texte_1
          << ligne_de_texte_2
          << ligne_de_texte_3
          << ligne_de_texte_4 >>

Une indentation des unités indique la profondeur d'imbrication.

tableau
-------
Le format tableau est le plus riche, car il note explicitement les infos
d'arborescence sous la forme d'un chemin (séquence des types relevés des
unités parentes).

Le parent direct dans le chemin est interprété comme une "zone"
(reporté colonne D et utilisé pour la position dans la zone - colonne F)

De plus, la sortie tableau ajoute une colonne "contexte gauche" qui fait
office de mini-concordancier : on y retrouve les 25 caractères précédant
l'unité. Le nombre de caractères est configurable par l'option -g

Colonnes :
  A) ID glozz
  B) type de l'unité
  C) attributs (séparateur = "/")
  D) zone (type parent)
  E) position début dans le corpus
  F) position début dans la zone
  G) longueur (en caractères)
  H) profondeur (d'imbrication)
  I) chemin (séparateur = "::")
  J) contexte gauche
  K) texte

Ces colonnes sont séparées par des tabulations (réglage par -s)

Pour ne pas affecter les lignes du tableau, les sauts de lignes dans les
les colonnes textes (J et K) sont remplacés par la chaine "<br>" ou une
autre chaîne spécifiée avec l'option -l.

pseudo-xml
----------
A toutes fins utiles, une sortie supplémentaire permet la présentation
des unités sous la forme d'un document d'inspiration XML.

Les éléments XML y sont en fait les types des unités. Les attributs sont
reportés comme attributs de l'élément. Le segment textuel correspondant
*et* tout élément imbriqué sont notés dans le contenu de l'élément XML...

Ce mélange de texte et d'éléments rend le format pour l'instant non
conforme aux normes XML... correction bientôt.

        = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
         version: 0.4 (18/12/2009)        contact: rloth at u-paris10 dot fr
        = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
         copyright 2009 laboratoire MoDyCo (UMR 7114 CNRS/Paris 10 Nanterre)
