<?php
    $user = '<user>';
    define('GITHUB_USER', '<user>');
    define('GITHUB_TOKEN', '<token>');

    $api = 'https://api.github.com/';
    $orgs = [];
    $output = [];

    $key = 0;

    function apiGet($url, $path) {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url . $path);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'GET');
        curl_setopt($ch, CURLOPT_USERPWD, GITHUB_USER . ':' . GITHUB_TOKEN);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.7113.93 Safari/537.36');
        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            return 'Error: ' . curl_error($ch);
        } else {
            return json_decode($result, true);
        }
        curl_close($ch);
    }

    function appendRepoToOutput($api, &$output, $repo, &$key) {
        $key++;
        $output[$key]['name'] = htmlentities($repo['name'], ENT_QUOTES);
        $output[$key]['fullName'] = htmlentities($repo['full_name'], ENT_QUOTES);
        $output[$key]['description'] = !empty($repo['description']) ? htmlentities($repo['description'], ENT_QUOTES) : 'null';
        $output[$key]['created'] = htmlentities(strtotime($repo['created_at']), ENT_QUOTES);
        $output[$key]['pushed'] = htmlentities(strtotime($repo['pushed_at']), ENT_QUOTES);
        $output[$key]['stars'] = htmlentities($repo['stargazers_count'], ENT_QUOTES);
        foreach(apiGet($api, "repos/{$repo['full_name']}/languages") as $lang=>$c) {
            $output[$key]['languages'][] = htmlentities($lang, ENT_QUOTES);
        }
        $output[$key]['languages'] = isset($output[$key]['languages']) ? $output[$key]['languages'] : 'null';
    }

    foreach(apiGet($api, "users/{$user}/orgs") as $org) {
        array_push($orgs, $org['login']);
    }

    foreach(apiGet($api, "users/{$user}/repos") as $repo) {
        appendRepoToOutput($api, $output, $repo, $key);
    }

    foreach($orgs as $org) {
        foreach(apiGet($api, "orgs/{$org}/repos") as $repo) {
            appendRepoToOutput($api, $output, $repo, $key);
        }
    }

    print_r($output);

    array_multisort(array_column($output, 'pushed'), SORT_DESC, $output);

    $finalOutput['repos'] = $output;
    $finalOutput['time'] = time();

    $json = json_encode($finalOutput);

    $file = fopen(__DIR__ . '/repos.json', 'w');
    fwrite($file, $json);
