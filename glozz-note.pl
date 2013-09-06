#! /usr/local/bin/perl -w
# ----------------------------------------------------------------------------------
# EXTRACTION DE SEGMENTS + DESCRIPTEURS DEPUIS LES UNITÉS D'UN CORPUS ANNOTÉ GLOZZ
# ----------------------------------------------------------------------------------
# Entrée: fichiers .aa (annotations) + .ac (corpus sur une ligne)
# Sortie: au choix listing (par déf.) ou tableau ou xml
# --------------------------------------------------------------------------------
#  message /help/ en fin de ce fichier       version: 0.4 (18/12/2009)
#  copyright 2009 CNRS UMR-7114 MoDyCo       contact: rloth at u-paris10 dot fr
# --------------------------------------------------------------------------------
# This program is free software : you can redistribute it and/or modify it under
# the terms of the *GNU Lesser General Public License* as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful but WITHOUT ANY
# WARRANTY ; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Lesser General Public License for details.
#
# A copy of the license can be found at <http://www.gnu.org/licenses/lgpl.txt>.
# --------------------------------------------------------------------------------

use warnings ;
use strict ;
use utf8 ;
use open ':encoding(UTF-8)' ;
binmode(STDOUT, ":utf8") ;
use Getopt::Std ; $Getopt::Std::STANDARD_HELP_VERSION = 1 ;
use Data::Dumper ;
use Data::Diver qw( Dive DiveVal DiveError );
use XML::Simple qw(:strict) ;

#------------------------------- options -----------------------------------------
# ligne de commande
my $opts = {} ;
getopts('C:A:l:dvnhg:xt', $opts) ;

# -h ou --help
HELP_MESSAGE() if ($opts->{h}) ;

# switch booléens -a -d -x -t
my $arbre     = $opts->{n} ?  0 : 1 ;
my $debug     = $opts->{d} || 0 ;
my $tableau   = $opts->{t} || 0 ;
my $pseudoxml = $opts->{x} || 0 ;

# sorties
die "OPTS!! Choisir svp une (seule) sortie parmi -t ou -x\n" if ($pseudoxml && $tableau) ;
die "OPTS!! La sortie xml (-x) nécessite l'arborescence (sans option -n)\n" if ($pseudoxml && !$arbre) ;
my $standard   = 1 unless ($tableau || $pseudoxml) ;

# séparateur de colonnes (mode tableau) et lignes texte (selon mode)
my $colnsep = $opts->{s} || "\t"   ;
my $retchar = $opts->{l} || ($tableau ? "<br>" : "\n" ) ;

# nombre de caractères pour le voisinage gauche du champ concordancier (mode tableau)
my $nbchars_contxt = $opts->{g} || 25 ;

#------------------------ variable globale $annotations ----------------------------------

my $annotations = {} ;
if (-e $opts->{A}) {  $annotations = parseXmlaa($opts->{A}) ; }
else { die "IN!! echec lecture AA sur $opts->{A} ($!)\n" }

#------------------------ variable globale $corpus ---------------------------------------
my $corpus = "" ;

# une seule très longue ligne
open (AC, "< $opts->{C}") || die "IN!! echec lecture AC sur $opts->{C} ($!)\n" ;
$corpus = <AC> ;
close AC ;

#------------------------ annotations dans l'ordre du texte -----------------------------

# on trie nos annotations selon un ordre à peu près judicieux
my @units = sort triInclusif @{$annotations->{'unit'}} ;

#------------------------ variable globale $newlines -------------------------------------
# $newlines
my $newlines  = [] ;

# on déplace les sauts de ligne dans un tableau distinct $newlines
while ('paragraph' eq uType($units[0])) {
	my $fin = uFin($units[0]) ;
	push (@$newlines, $fin) ;
	shift @units ;
}

# NB:tous les <paragraph> sont groupés dans l'ordre
#   au *début* des unités du xml aa (permet le shift)
if ($debug) {
	warn "NEWLINES : ".join(';', @{$newlines})."\n" ;
}

#-------------------------------- boucle centrale -------------------------------

print "<corpus>\n" if ($pseudoxml) ;

# tracking de la zone courante pour recréer une arborescence
my @p_noms  = ( 'corpus' ) ;
my @p_stops = ( length $corpus ) ;
my @p_debs  = ( 0 ) ;
my $profondeur = 0 ;

my $nom_zone ;
my $deb_zone ;

foreach my $ce_tag (@units) {

	my $type = uType ($ce_tag) ;
	my $deb  = uDebut($ce_tag) ;
	my $fin  = uFin  ($ce_tag) ;

	if ($arbre) {
		my $avant = $profondeur ;
		my $stop = $p_stops[$avant] || die "tree array index $!" ;

		# m.à.j. pointage dans l'arbre
		# on enlève les candidats-pères impossibles de la pile pour se ramener au vrai père
		while ($stop <= $deb) {
			if ($pseudoxml) {
				my $ex_type = pop @p_noms ;
				my $tabs = "  " x ($arbre ? $profondeur : 1) ;
				print "$tabs</".$ex_type.">\n" ;
			}
			else { pop @p_noms ; }
			pop @p_stops ;
			pop @p_debs ;
			$profondeur-- ;
			$stop = $p_stops[$profondeur] || die "tree array index $!" ;
		}

		# position stabilisée
		warn "#c $deb  ||  <var ".lc($avant-$profondeur-1).">\n" if ($debug) ;
		$nom_zone = $p_noms[$profondeur] ;
		$deb_zone = $p_debs[$profondeur] ;

		# l'annotation $ce_tag devient un père potentiel pour les unités qui viendront
		# (ajout du nom et de la fin aux registres)
		push (@p_noms, $type) ;
		push (@p_stops, $fin) ;
		push (@p_debs, $deb) ;
		$profondeur++ ;
	}

	my $attributs = join (($pseudoxml ? ' ' : '/'), @{ uAttributs($ce_tag) }) ;
	my @taggedtxt = @{ reconstitution($deb, $fin) } ;

	if ($standard) {
		my $tabs = "  " x ($arbre ? $profondeur : 1) ;
		print "\n".$tabs.'['.$type.']--{'.$attributs.'}--@('.$deb.'..'.$fin.")\n" ;
		print $tabs." << ".join("\n$tabs << ", @taggedtxt)." >>\n\n" ;
	}

	if ($tableau) {
		my $txt = join($retchar,@taggedtxt) ;
		print join($colnsep, (
							# glozzid
							uId($ce_tag),
							# type et attributs de l'unité
							$type,
							$attributs,
							# zone parent
							$nom_zone,
							# début dans le corpus
							$deb,
							# position début par rapport au parent
							$deb-$deb_zone,
							# longueur
							$fin-$deb ,
							# profondeur
							$profondeur,
							# chemin
							join('::',@p_noms),
							# contexte gauche
							gauche($deb) ,
							$txt,
							))."\n" ;
	}

	if ($pseudoxml) {
		my $element = $p_noms[$profondeur] ;
		my $tabs  = "  " x ($arbre ? $profondeur : 1) ;
		my $print = join("\n".$tabs."  ", @taggedtxt) ;
		chomp $print ;
		print $tabs."<$element $attributs start=\"$deb\" end=\"$fin\">\n" ;
		print $tabs."  ".$print."\n" ;
	}


	if ($debug && $arbre) {
		warn "loc :  ".join('::',@p_noms)."\n" ;
		warn "lims:  ".join('<',reverse @p_stops)."\n" ;
		warn "   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -   \n" ;
	}
}

# dégression contrôlée pour clore les "éléments xml"
while ($pseudoxml && ($profondeur >= 0)) {
	my $stop = $p_stops[$profondeur] || die "aaaaaaargh $!" ;
	# m.à.j. pointage dans l'arbre
	my $ex_type = pop @p_noms ;
	print '</'.$ex_type.">\n" ;
	pop @p_stops ;
	$profondeur-- ;
	$stop = $p_stops[$profondeur] || "" ;
}

print "</corpus>\n" if ($pseudoxml) ;

# Fin



#-------------------------------- SUBS -------------------------------------------

sub triInclusif {
	my $comparaison = 0 ;
	# warn "---".uType($a)."---".uType($b)."---\n" ;

	# le début du test met les paragraphes en premier
	# pour faciliter les traitements suivants
	if (uType($a) eq "paragraph") {
		if (uType($b) eq "paragraph") {
			$comparaison = uDebut($a) <=> uDebut($b) ;
		}
		else { $comparaison = -1 ; }
	}
	elsif (uType($b) eq "paragraph") { $comparaison = 1 ;}
	else {
		# ce tri reproduit un peu l'arborescence des sections
		# (au fil du texte en mettant les contenants avant les contenus)
		$comparaison = uDebut($a) <=> uDebut($b) || uFin($b) <=> uFin($a) ;
	}

	# warn "return : ".$comparaison ."\n---------------------\n" ;
	return $comparaison ;

	###### Exemple ###############################################
	# Paragraph[0..155]
	# Paragraph[155..279]
	# Paragraph[279..303]
	# Annonce-Poste-Courte[155..303] "TRUC, industrie agro-alimentaire de 420
	#                                 salariés située à Bayeux dans le Calvados,
	#                                 recherche au sein du Département Qualité :
	#                                 Assistant Qualité h/f"
	# Etablissement[155..160]   "TRUC"
	# Secteur[172..188]         "agro-alimentaire"
	# Etablissement[192..204]   "420 salariés"
	# Mobilité[213..237]        "Bayeux dans le Calvados"
	# Conditions[260..279]      "Département Qualité"
	# Poste[282..299]           "Assistant Qualité"
	##############################################################
}

### ---- getters pour les éléments xml <unit> ----
sub uFin {
	my $unit = shift ;
	# int
	return Dive($unit, 'positioning', 'end') ;
}

sub uDebut {
	my $unit = shift ;
	# int
	return Dive($unit, 'positioning', 'start') ;
}

sub uType {
	my $unit = shift ;
	# string
	return Dive($unit, 'characterisation', 'type') ;
}

sub uAttributs {
	my $unit = shift ;
	my $attributs = [] ;
	my $ftHash = Dive($unit, 'characterisation', 'featureSet') ;
	for my $ftName (keys %$ftHash) {
		my $valeur = Dive($ftHash, $ftName, 'content') ;
		# on ignore les attributs à valeurs nulles
		if ($valeur) {
			if ($pseudoxml) {
				push (@$attributs, $ftName.'="'.$valeur.'"') ;
			}
			else {
				# --> insérer ici tout traitement spécifique <--
				# par ex:
				#  booléen   =>   omettre la valeur     => push (@$attributs, $ftName) ;
				#  txt libre => garder juste la valeur  => push (@$attributs, $valeur) ;
				#  etc.
				push (@$attributs, $ftName.'="'.$valeur.'"') ;
			}
		}
	}
	# arrayref
	return $attributs ;
}

sub uId {
	my $unit = shift ;
	# string
	return Dive($unit, 'id') ;
}

### ---- UTILITAIRES ----

# récupère un texte sans sauts de ligne entre 2 positions
# utilise LA VARIABLE GLOBALE $corpuscd
sub cpZoneTxt {
	my $start = shift ;
	my $end = shift ;
	return substr ($corpus, $start, $end-$start) ;
}

# Reconstitution de txt
# (réinsertion de sauts de ligne pour n'importe quelle zone)
# NB : le texte reconstitué n'est plus utilisable avec les 'positions'
#      car l'ajout des sauts de ligne modifie l'index des caractères
#      ... donc cette sub doit intervenir juste avant la sortie
# utilise LA VARIABLE GLOBALE $newlines
# utilise LA VARIABLE GLOBALE $corpus
sub reconstitution {
	my $debut_zone = shift ;
	my $fin_zone   = shift ;

	my @lignes = () ;
	my $texte_zone = cpZoneTxt($debut_zone, $fin_zone) ;
	my $pointeur = 0 ;
	for my $saut (@{$newlines}) {
		next if ($saut <= $debut_zone) ;

		my $saut_reindexed = $saut-$debut_zone ;
		my $vraieligne = substr ($texte_zone, $pointeur, $saut_reindexed-$pointeur) ;
		# on omet les lignes vides
		push (@lignes, $vraieligne) if ($vraieligne) ;
		$pointeur = $saut_reindexed ;

		last if ($saut > $fin_zone) ;
	}
	# warn "-  -  -  -  -  -  -  -  -\n" ;
	# warn "appel à réinsertion\n" ;
	# warn Dumper \@lignes ;
	# warn "-  -  -  -  -  -  -  -  -\n" ;
	return \@lignes ;
}

# voisinage gauche d'une position (longeur par défaut : 25 caractères)
# utilise LA VARIABLE GLOBALE $corpus
sub gauche {
	my $start = shift ;
	my $avant = ($start > $nbchars_contxt) ? ($start - $nbchars_contxt) : 0 ;
	# string
	return join($retchar, @{reconstitution($avant, $start)}) ;
}

# Parse le XML des fichiers .aa
sub parseXmlaa {
	my $xmlpath = shift ;
	my $xmlproc = new XML::Simple ;

	# lecture xml et simplifications arbre dom
	my $xml = $xmlproc->XMLin( $xmlpath,
								ForceArray => [ 'unit', 'relation', 'feature' ] ,
								GroupTags  => { singlePosition => 'index' ,
											    end   => 'singlePosition' ,
											    start => 'singlePosition' ,
											    featureSet => 'feature',
											  } ,
								KeyAttr    => { feature => 'name' },
								SuppressEmpty => 1 ,
							);

	# STRUCTURE ATTENDUE
	#
	# $VAR1 = {
	#      'unit' => [
	# ============================ unités paragraphes =================================
	#                {
	#                  'positioning' => {
	#                                   'end' => '27',
	#                                   'start' => '0'
	#                                 },
	#                  'characterisation' => {
	#                                        'featureSet' => {},
	#                                        'type' => 'paragraph'
	#                                      },
	#                  'metadata' => {
	#                                'creation-date' => '-1',
	#                                'author' => 'anonymous'
	#                              },
	#                  'id' => 'anonymous_-1'
	#                },
	#                {
	#                  'positioning' => {
	#                                   'end' => '73',
	#                                   'start' => '27'
	#                                 },
	#                  'characterisation' => {
	#                                        'featureSet' => {},
	#                                        'type' => 'paragraph'
	#                                      },
	#                  'metadata' => {
	#                                'creation-date' => '-2',
	#                                'author' => 'anonymous'
	#                              },
	#                  'id' => 'anonymous_-2'
	#                },
	#
	#                      ETC paragraph
	#
	# =============== unités d'annotations proprement dites ===========================
	#                {
	#                  'positioning' => {
	#                                   'end' => '975',
	#                                   'start' => '601'
	#                                 },
	#                  'characterisation' => {
	#                                        'featureSet' => {},
	#                                        'type' => 'Profil-Candidat'
	#                                      },
	#                  'metadata' => {
	#                                'creation-date' => '1259605856921',
	#                                'author' => 'rloth'
	#                              },
	#                  'id' => 'rloth_1259605856921'
	#                },
	#                {
	#                  'positioning' => {
	#                                   'end' => '1214',
	#                                   'start' => '975'
	#                                 },
	#                  'characterisation' => {
	#                                        'featureSet' => {},
	#                                        'type' => "Contact-Modalit\x{e9}s"
	#                                      },
	#                  'metadata' => {
	#                                'creation-date' => '1259605862500',
	#                                'author' => 'rloth'
	#                              },
	#                  'id' => 'rloth_1259605862500'
	#                },
	#                {
	#                  'positioning' => {
	#                                   'end' => '90',
	#                                   'start' => '73'
	#                                 },
	#                  'characterisation' => {
	#                                        'featureSet' => {
	#                                                        'theme_objet' => {
	#                                                                         'content' => '1'
	#                                                                       },
	#                                                        'nom_metier_compo' => {
	#                                                                              'content' => '0'
	#                                                                            },
	#                                                        'intitule' => {
	#                                                                      'content' => '1'
	#                                                                    },
	#                                                        'autres' => {},
	#                                                        'nom_metier_simple' => {
	#                                                                               'content' => '0'
	#                                                                             },
	#                                                        'niveau_hierar' => {
	#                                                                           'content' => '1'
	#                                                                         },
	#                                                        'agent_divers' => {
	#                                                                          'content' => '0'
	#                                                                        },
	#                                                        'theme_vide' => {
	#                                                                        'content' => '0'
	#                                                                      },
	#                                                        'service_lieu' => {
	#                                                                          'content' => '0'
	#                                                                        }
	#                                                      },
	#                                        'type' => 'Poste'
	#                                      },
	#                  'metadata' => {
	#                                'creation-date' => '1259605876453',
	#                                'author' => 'rloth'
	#                              },
	#                  'id' => 'rloth_1259605876453'
	#                },
	#
	#              ],
	# ===================================================================================================
	#  'relation' => [ * ne seront pas utilisées * ]
	#  'schema'   => [ * ne seront pas utilisés  * ]

	return $xml ;
}


sub HELP_MESSAGE {
	print <<EOT;
--------------------------------------------------------------------
| Post-traitement de corpus annoté sous plate-forme GLOZZ du GREYC |
|------------------------------------------------------------------|
| Usage:                                                           |
|   perl glozz-note.pl -A chemin/corpus.aa -C chemin/corpus.ac     |
|                                                                  |
| Options:                                                         |
|   -t     passer en sortie tableau (séparé par des tabs)          |
|   -x     passer en sortie pseudo-xml (éléments=types)            |
|   -d     afficher les infos de debogage à la lecture             |
|   -h     afficher cet écran                                      |
|   -n     ne pas recréer l'arbre des unités imbriquées            |
|          (à utiliser si les annotations se chevauchent beaucoup) |
|                                                                  |
| Arguments:                                                       |
|   -C corpus.ac    fichier .ac (entrée texte sur une ligne)       |
|   -A corpus.aa    fichier .aa (entrée annotations xml)           |
|   -g 70           nombre de caractères pour le contexte gauche   |
|                   (colonne du mode tableau, défaut=25)           |
|   -s ";"          séparateur de colonne pour la sortie tableau   |
|                   (par défaut = tabulations)                     |
|   -l " "          dans les données texte, sauts de lignes        |
|                   (par défaut, en tableau = '<br>'               |
|                    par défaut, en listing et en xml = '\\n' )     |
|                                                                  |
| Sortie:                                                          |
|      Segments textuels et détail de leurs annotations            |
|------------------------------------------------------------------|
| GNU-LGPL © 2009 MoDyCo CNRS UMR 7114 · rloth at u-paris10 dot fr |
--------------------------------------------------------------------
EOT
	exit 0 ;
}
