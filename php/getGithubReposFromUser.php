<?php
    $user = '<user>';
    $token = '<token>';
    $apiUrl = 'https://api.github.com/';

     function apiGet($path) {
        global $apiUrl;
        global $token;
        global $user;

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $apiUrl . $path);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'GET');
        curl_setopt($ch, CURLOPT_USERPWD, $user . ':' . $token);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 6.2; WOW64; rv:17.0) Gecko/20100101 Firefox/17.0');
        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            return 'Error:' . curl_error($ch);
        } else {
            return json_decode($result, true);
        }

        curl_close($ch);
    }

    $repos = apiGet('users/' . $user . '/repos');

    foreach($repos as $key=>$repo) {
        $reposP['repos'][$key]['name'] = htmlentities($repo['name'], ENT_QUOTES);
        $reposP['repos'][$key]['fullName'] = htmlentities($repo['full_name'], ENT_QUOTES);
        $reposP['repos'][$key]['description'] = !empty($repo['description']) ? htmlentities($repo['description'], ENT_QUOTES) : 'leer';
        $reposP['repos'][$key]['created'] = htmlentities(strtotime($repo['created_at']), ENT_QUOTES);
        $reposP['repos'][$key]['pushed'] = htmlentities(strtotime($repo['pushed_at']), ENT_QUOTES);
        $reposP['repos'][$key]['stars'] = htmlentities($repo['stargazers_count'], ENT_QUOTES);
        $langs = apiGet('repos/' . $repo['full_name'] . '/languages');
        foreach($langs as $lang=>$amt) {
            $reposP['repos'][$key]['languages'][] = htmlentities($lang, ENT_QUOTES);
        }
    }

    $reposP['updated'] = time();

    $json = json_encode($reposP);

    $file = fopen("repos.json", "w");
    fwrite($file, $json);
