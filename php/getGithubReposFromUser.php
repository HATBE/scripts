<?php
    require_once(__DIR__ . '/../../config/auth.php');

    $user = '<user>';
    define('GITHUB_USER', '<user>');
    define('GITHUB_TOKEN', '<token>');

    $output = [];
    $key = 0;

    function callApi($query, $variables) {
        $json = json_encode(['query' => $query, 'variables' => $variables]);
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, 'https://api.github.com/graphql');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'POST');
        curl_setopt($ch, CURLOPT_USERPWD, GITHUB_USER . ':' . GITHUB_TOKEN);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json);
        curl_setopt($ch, CURLOPT_USERAGENT, 'bitsflipped.ch - badges - BOT');
        curl_setopt($ch, CURLOPT_HTTPHEADER, array('Accept: application/json'));
        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            return 'Error: ' . curl_error($ch);
        } else {
            return json_decode($result, true);
        }
        curl_close($ch);

        return $result;
    }

    function getData($username) {
        $query = '
        query userData($login: String!) {
            user(login: $login) {
                repositories (first: 100, privacy: PUBLIC, orderBy: {direction: DESC, field: STARGAZERS}) {
                    nodes {
                        name
                        nameWithOwner
                        stargazerCount
                        createdAt
                        pushedAt
                        description
                        url
                        owner {
                            login
                        }
                        languages(first: 100) {
                            nodes {
                                name
                                color
                            }
                        }
                    }
                }
                repositoriesContributedTo (first: 100, privacy: PUBLIC, orderBy: {direction: DESC, field: STARGAZERS}) {
                    nodes {
                        name
                        nameWithOwner
                        stargazerCount
                        createdAt
                        pushedAt
                        description
                        url
                        owner {
                            login
                        }
                        languages(first: 100) {
                            nodes {
                                name
                                color
                            }
                        }
                    }
                }
            }
        }
        ';

        $variables = json_encode(['login' => $username]);
        $data = callApi($query, $variables);

        return $data;
    }

    function appendRepoToOutput(&$output, $repo, &$key) {
        $output[$key]['owner'] = htmlspecialchars($repo['owner']['login']);
        $output[$key]['name'] = htmlspecialchars($repo['name']);
        $output[$key]['fullName'] = htmlspecialchars($repo['nameWithOwner']);
        $output[$key]['description'] = !empty($repo['description']) ? htmlspecialchars($repo['description']) : null;
        $output[$key]['created'] = htmlspecialchars(strtotime($repo['createdAt']));
        $output[$key]['pushed'] = htmlspecialchars(strtotime($repo['pushedAt']));
        $output[$key]['stars'] = htmlspecialchars($repo['stargazerCount']);
        $subkey = 0;
        foreach($repo['languages']['nodes'] as $lang) {
            $output[$key]['languages'][$subkey]['language'] = $lang ['name'];
            $output[$key]['languages'][$subkey]['color'] = $lang ['color'];
            $subkey++;
        }
        $key++;
    }

    function addAllRepos($data, &$output, &$key) {
        $data = $data['data']['user'];
        $own = $data['repositories']['nodes'];
        $rct = $data['repositoriesContributedTo']['nodes'];

        foreach($own as $repo) {
            appendRepoToOutput($output, $repo, $key);
        }

        foreach($rct as $repo) {
            appendRepoToOutput($output, $repo, $key);
        }
    }

    $data = getData($user);
    addAllRepos($data, $output, $key);

    array_multisort(array_column($output, 'pushed'), SORT_DESC, $output);

    $finalOutput['repos'] = $output;
    $finalOutput['time'] = time();

    $json = json_encode($finalOutput);

    $file = fopen(__DIR__ . '/../data/repos.json', 'w');
    fwrite($file, $json);
