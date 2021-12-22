<?php
    $token = '<token>';
    $apiUrl = 'https://api.github.com/';
    $user = '<user>'

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
        $reposP[$key]['name'] = $repo['name'];
        $reposP[$key]['fullName'] = $repo['full_name'];
        $reposP[$key]['description'] = !empty($repo['description']) ? $repo['description'] : 'leer';
        $reposP[$key]['created'] = strtotime($repo['created_at']);
        $reposP[$key]['pushed'] = strtotime($repo['pushed_at']);
        $reposP[$key]['language'] = $repo['language'];
        $reposP[$key]['stars'] = $repo['stargazers_count'];
    }

    $json = json_encode($reposP);

    $file = fopen('repos.json', 'w');
    fwrite($file, $json);
