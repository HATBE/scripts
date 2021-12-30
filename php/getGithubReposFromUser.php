<?php
    require_once(__DIR__ . '/../config/auth.php');

    $user = '<user>';
    define('GITHUB_USER', '<user>');
    define('GITHUB_TOKEN', '<token>');

    $api = 'https://api.github.com/';
    $orgs = [];
    $output = [];

    function apiGet($url, $path) {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url . $path);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'GET');
        curl_setopt($ch, CURLOPT_USERPWD, GITHUB_USER . ':' . GITHUB_TOKEN);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.7113.93 Safari/537.36');
        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            echo 'Error: ' . curl_error($ch);
            exit();
        } else {
            return json_decode($result, true);
        }
        curl_close($ch);
    }

    function appendRepoToOutput(&$output, $key, $repo) {
        global $api;
        $output['repos'][$key]['name'] = htmlentities($repo['name'], ENT_QUOTES);
        $output['repos'][$key]['fullName'] = htmlentities($repo['full_name'], ENT_QUOTES);
        $output['repos'][$key]['description'] = !empty($repo['description']) ? htmlentities($repo['description'], ENT_QUOTES) : null;
        $output['repos'][$key]['created'] = htmlentities(strtotime($repo['created_at']), ENT_QUOTES);
        $output['repos'][$key]['pushed'] = htmlentities(strtotime($repo['pushed_at']), ENT_QUOTES);
        $output['repos'][$key]['stars'] = htmlentities($repo['stargazers_count'], ENT_QUOTES);
        foreach(apiGet($api, "repos/{$repo['full_name']}/languages") as $lang=>$c) {
            $output['repos'][$key]['languages'][] = htmlentities($lang, ENT_QUOTES);
        }
    }

    foreach(apiGet($api, "users/{$user}/orgs") as $org) {
        array_push($orgs, $org['login']);
    }

    foreach(apiGet($api, "users/{$user}/repos") as $key=>$repo) {
        appendRepoToOutput($output, $key, $repo);
    }

    foreach($orgs as $org) {
        foreach(apiGet($api, "orgs/{$org}/repos") as $key=>$repo) {
            appendRepoToOutput($output, $key, $repo);
        }
    }

    $output['time'] = time();

    print_r($output);

    $json = json_encode($output);

    $file = fopen(__DIR__ . '/repos.json', 'w');
    fwrite($file, $json);
