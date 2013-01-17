<?

$FILENAME = 'scoreboard.json';

if (file_exists($FILENAME)) {
    $scoreboard = json_decode(file_get_contents($FILENAME));
} else {
    $scoreboard = array();
}

// function cmp($a, $b) {
//     if ($a->score == $b->score) {
//         return 0;
//     }
//     return ($a->score > $b->score) ? -1 : 1;
// }

if (isset($_POST['signature'])) {
    $newHighScore = base64_decode($_POST['data']);
    $json = json_decode($newHighScore);

    if ($_POST['signature'] === md5($newHighScore) && (sizeof($scoreboard) === 0 || $json->score >= $scoreboard[0]->score)) {
        array_unshift($scoreboard, $json);
        // usort($scoreboard, "cmp");

        if (sizeof($scoreboard) > 10) {
            $scoreboard = array_slice($scoreboard, 0, 10);
        }

        file_put_contents($FILENAME, json_encode($scoreboard));
    }
}

header('Content-Type: application/json');
echo json_encode($scoreboard);
