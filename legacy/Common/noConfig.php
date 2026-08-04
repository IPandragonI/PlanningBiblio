<?php
/**
Planning Biblio, Version 1.9.5
Licence AGPL (version 3 et au dela)
Voir les fichiers README.md et LICENSE
@copyright 2011-2018 Jérôme Combes

Fichier : include/noConfig.php
Création : 8 avril 2015
Dernière modification : 8 avril 2015
@author Jérôme Combes <jerome@planningbiblio.fr>

Description :
Affiche une page renvoyant vers le fichier setup/index.php si le fichier de configuration est absent

Page appelée (include) par le fichier et index.php si le fichier include/config.php est absent
*/

$scriptFilename = isset($_SERVER['SCRIPT_FILENAME']) ? (string) $_SERVER['SCRIPT_FILENAME'] : '';
$scriptFilename = str_replace('\\', '/', $scriptFilename);

// Contrôle si ce script est appelé directement, dans ce cas, affiche Accès Refusé et quitte
if (__FILE__ == $scriptFilename) {
    include_once(__DIR__.'/../include/accessDenied.php');
    exit;
}

$publicDir = str_replace('\\', '/', dirname(__DIR__)); // .../public
$path = '';

if ($scriptFilename !== '' && str_starts_with($scriptFilename, $publicDir)) {
    $relative = ltrim(substr($scriptFilename, strlen($publicDir)), '/');
    $depth = max(0, substr_count($relative, '/') - 1);
    $path = str_repeat('../', $depth);
}

?>
<!DOCTYPE html>
<html>
<head>
<title>Planning</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Poppins">
<link rel='StyleSheet' href='<?php echo $path; ?>themes/default/default.css' type='text/css' media='all'/>
</head>

<body>
<div id='auth-logo'></div>
<h2 id='h2-authentification'>Fichier de configuration manquant</h2>
<center>
<strong>
Le fichier de configuration est manquant.<br/> 
<a href='setup'>Cliquez ici pour commencer l'installation.</a>
</strong>
</center>
<?php
include(__DIR__.'/footer.php');
exit;
?>